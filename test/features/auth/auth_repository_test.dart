import 'dart:io';

import 'package:esas/core/network/api_error_mapper.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/auth/data/services/auth_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthApi extends Mock implements AuthApiService {}

void main() {
  late _MockAuthApi api;
  late InMemoryLocalStorage local;
  late InMemoryTokenStorage tokens;
  late SessionRepository session;
  late AuthRepository auth;

  const userJson = {
    'id': 7,
    'name': 'Budi',
    'nip': '20240113',
    'company': {'latitude': -6.17566, 'longitude': 106.59925},
    'employee': {'departement_id': 3, 'user_id': 7},
  };

  setUp(() {
    api = _MockAuthApi();
    local = InMemoryLocalStorage();
    tokens = InMemoryTokenStorage();
    session = SessionRepository(tokenStorage: tokens, localStorage: local);
    auth = AuthRepository(api: api, session: session);
  });

  group('login', () {
    test('persists the session and returns the user', () async {
      when(
        () => api.login(
          identifier: any(named: 'identifier'),
          password: any(named: 'password'),
          deviceId: any(named: 'deviceId'),
        ),
      ).thenAnswer((_) async => {'token': 'abc', 'user': userJson});

      final user = await auth.login(
        identifier: '20240113',
        password: 'hunter2',
        deviceId: 'device-1',
      );

      expect(user.name, 'Budi');
      expect(session.token, 'abc');
      expect(auth.isAuthenticated, isTrue);
    });

    test('never stores the password anywhere', () async {
      // CRIT-03. The password authenticates and is then dropped.
      when(
        () => api.login(
          identifier: any(named: 'identifier'),
          password: any(named: 'password'),
          deviceId: any(named: 'deviceId'),
        ),
      ).thenAnswer((_) async => {'token': 'abc', 'user': userJson});

      await auth.login(identifier: 'x', password: 'hunter2', deviceId: 'd');

      final everythingStored = local.read<dynamic>('auth_user_json').toString();
      expect(everythingStored, isNot(contains('hunter2')));
      expect(local.hasData('auth_user_password'), isFalse);
    });

    test('rejects a response that is missing the token', () async {
      when(
        () => api.login(
          identifier: any(named: 'identifier'),
          password: any(named: 'password'),
          deviceId: any(named: 'deviceId'),
        ),
      ).thenAnswer((_) async => {'user': userJson});

      await expectLater(
        auth.login(identifier: 'x', password: 'y', deviceId: 'd'),
        throwsA(isA<ApiException>()),
      );
      expect(auth.isAuthenticated, isFalse);
    });
  });

  group('restoreSession — the three-way outcome (HIGH-02)', () {
    setUp(() async {
      await session.save(token: 'abc', user: AuthUser.fromJson(userJson));
    });

    test('absent when there is no credential', () async {
      await session.clear();

      expect(await auth.restoreSession(), SessionState.absent);
      verifyNever(() => api.currentUser());
    });

    test('authenticated when the server confirms it', () async {
      when(() => api.currentUser()).thenAnswer((_) async => {'user': userJson});

      expect(await auth.restoreSession(), SessionState.authenticated);
      expect(session.token, 'abc');
    });

    test('expired ONLY on a 401, and the session is cleared', () async {
      when(
        () => api.currentUser(),
      ).thenThrow(const ApiException('nope', status: 401));

      expect(await auth.restoreSession(), SessionState.expired);
      expect(session.token, isNull);
      expect(local.hasData('auth_user_json'), isFalse);
    });

    test('OFFLINE on a dead socket — the session is KEPT', () async {
      // The bug this closes: the old probe swallowed SocketException in a bare
      // `catch (_) {}`, returned false, and the caller wiped the session. Opening
      // the app with no signal signed the employee out at the factory gate.
      when(() => api.currentUser()).thenThrow(
        ApiErrorMapper.fromTransportError(const SocketException('no route')),
      );

      expect(await auth.restoreSession(), SessionState.offline);
      expect(session.token, 'abc', reason: 'the credential must survive');
      expect(session.user?.name, 'Budi');
    });

    test('offline on a timeout — the session is kept', () async {
      when(
        () => api.currentUser(),
      ).thenThrow(const ApiException('slow', code: 'timeout'));

      expect(await auth.restoreSession(), SessionState.offline);
      expect(session.token, 'abc');
    });

    test('offline on a 5xx — a broken server is not a dead session', () async {
      when(
        () => api.currentUser(),
      ).thenThrow(const ApiException('boom', status: 503));

      expect(await auth.restoreSession(), SessionState.offline);
      expect(session.token, 'abc');
    });

    test('a 403 does not end the session either', () async {
      // R-07: 403 means this account may not do this thing. Signing them out
      // would eject a perfectly well authenticated user.
      when(
        () => api.currentUser(),
      ).thenThrow(const ApiException('forbidden', status: 403));

      expect(await auth.restoreSession(), SessionState.offline);
      expect(session.token, 'abc');
    });

    test('expired when a 200 does not describe a user', () async {
      when(() => api.currentUser()).thenAnswer((_) async => {'ok': true});

      expect(await auth.restoreSession(), SessionState.expired);
      expect(session.token, isNull);
    });
  });

  group('logout', () {
    setUp(() async {
      await session.save(token: 'abc', user: AuthUser.fromJson(userJson));
    });

    test('clears the session on success', () async {
      when(
        () => api.logout(fcmToken: any(named: 'fcmToken')),
      ).thenAnswer((_) async => {});

      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
    });

    test('melepas token push bersama permintaan keluar', () async {
      // Handset yang dipakai bergantian: tanpa ini ia tetap terdaftar atas nama
      // karyawan sebelumnya, dan notifikasi miliknya — cuti, gaji, absensi —
      // terus mendarat di layar orang berikutnya.
      when(
        () => api.logout(fcmToken: any(named: 'fcmToken')),
      ).thenAnswer((_) async => {});

      final withPush = AuthRepository(
        api: api,
        session: session,
        currentPushToken: () async => 'fcm-token-abc',
      );

      await withPush.logout();

      verify(() => api.logout(fcmToken: 'fcm-token-abc')).called(1);
    });

    test('keluar tetap berjalan ketika token push tidak terbaca', () async {
      // Push yang bermasalah tidak boleh menjadi alasan seseorang tidak bisa
      // keluar dari akunnya.
      when(
        () => api.logout(fcmToken: any(named: 'fcmToken')),
      ).thenAnswer((_) async => {});

      final broken = AuthRepository(
        api: api,
        session: session,
        currentPushToken: () async => throw StateError('firebase down'),
      );

      await broken.logout();

      expect(broken.isAuthenticated, isFalse);
      verify(() => api.logout(fcmToken: null)).called(1);
    });

    test('build tanpa push tetap keluar dengan bersih', () async {
      when(
        () => api.logout(fcmToken: any(named: 'fcmToken')),
      ).thenAnswer((_) async => {});

      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      verify(() => api.logout(fcmToken: null)).called(1);
    });

    test('clears the session even when the server refuses', () async {
      // LOW-05: the old logout only cleared on a 200, so a failed logout left
      // the employee signed in against a session the server may have dropped.
      when(
        () => api.logout(fcmToken: any(named: 'fcmToken')),
      ).thenThrow(const ApiException('boom', status: 500));

      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(local.hasData('auth_user_json'), isFalse);
    });
  });

  test('expireSession clears everything', () async {
    await session.save(token: 'abc', user: AuthUser.fromJson(userJson));

    await auth.expireSession();

    expect(auth.isAuthenticated, isFalse);
  });
}
