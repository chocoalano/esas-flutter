import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/auth/data/services/auth_api_service.dart';
import 'package:esas/features/auth/data/services/firebase_identity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements AuthApiService {}

class _Identity extends Mock implements FirebaseIdentityService {}

/// AUTH-02. A session ends in several ways — signing out, a 401 mid-session,
/// a token found expired at start, a sign-out with no connection. Only a
/// successful sign-out used to release the handset: the others cleared the
/// local token and left the push token registered to the previous employee
/// (their payslip and leave notifications kept arriving on a shared phone) and
/// left them signed in to Google for the next person's "Masuk dengan Google".
void main() {
  late _Api api;
  late _Identity identity;
  late SessionRepository session;
  late AuthRepository auth;
  late int discarded;

  setUp(() async {
    api = _Api();
    identity = _Identity();
    discarded = 0;
    when(() => identity.signOut()).thenAnswer((_) async {});

    session = SessionRepository(
      tokenStorage: InMemoryTokenStorage(),
      localStorage: InMemoryLocalStorage(),
    );
    await session.save(
      token: 'abc',
      user: AuthUser.fromJson({'id': 7, 'name': 'Budi'}),
    );

    auth = AuthRepository(
      api: api,
      session: session,
      identity: identity,
      currentPushToken: () async => 'fcm-token',
      discardPushToken: () async => discarded++,
    );
  });

  void expectReleased() {
    expect(session.isAuthenticated, isFalse);
    expect(session.user, isNull);
    expect(discarded, 1, reason: 'the push token must not outlive the session');
    verify(() => identity.signOut()).called(1);
  }

  test('a 401 mid-session releases the handset', () async {
    await auth.expireSession();

    expectReleased();
  });

  test('a token found expired at start releases the handset', () async {
    when(
      () => api.currentUser(),
    ).thenThrow(const ApiException('expired', status: 401));

    expect(await auth.restoreSession(), SessionState.expired);
    expectReleased();
  });

  test('signing out with no connection still releases the handset', () async {
    when(
      () => api.logout(fcmToken: any(named: 'fcmToken')),
    ).thenThrow(const ApiException('offline', code: 'network_unreachable'));

    await auth.logout();

    expectReleased();
  });

  test('signing out normally releases it too, and tells the server', () async {
    when(
      () => api.logout(fcmToken: any(named: 'fcmToken')),
    ).thenAnswer((_) async => <String, dynamic>{});

    await auth.logout();

    verify(() => api.logout(fcmToken: 'fcm-token')).called(1);
    expectReleased();
  });

  test('a push token that will not go quietly does not block sign-out', () async {
    final stubborn = AuthRepository(
      api: api,
      session: session,
      identity: identity,
      discardPushToken: () async => throw StateError('plugin gone'),
    );

    await stubborn.expireSession();

    expect(session.isAuthenticated, isFalse);
    verify(() => identity.signOut()).called(1);
  });

  // UAT review C6. FCM's deleteToken has no deadline of its own; an offline
  // sign-out, and the navigation after a 401, waited for it.
  test('a push token that never answers does not hold the sign-out', () async {
    final stuck = AuthRepository(
      api: api,
      session: session,
      identity: identity,
      discardPushToken: () => Completer<void>().future,
      pushTokenTimeout: const Duration(milliseconds: 50),
    );

    await stuck.expireSession().timeout(const Duration(seconds: 2));

    expect(session.isAuthenticated, isFalse);
    verify(() => identity.signOut()).called(1);
  });
}
