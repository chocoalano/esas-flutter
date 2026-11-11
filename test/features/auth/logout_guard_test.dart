import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/auth/data/services/auth_api_service.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/profile/data/models/user.dart';
import 'package:esas/features/profile/data/repositories/profile_repository.dart';
import 'package:esas/features/profile/presentation/controllers/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements AuthApiService {}

class _Auth extends Mock implements AuthRepository {}

class _Repo extends Mock implements ProfileRepository {}

void main() {
  // AUTH-06. Signing out with a token the server had already dropped: the
  // logout request came back 401, the 401 handler ended the session and went
  // to the sign-in screen, and then the deliberate sign-out ended it again and
  // went there a second time.
  group('a 401 during a deliberate sign-out', () {
    late _Api api;
    late SessionRepository session;
    late AuthRepository auth;
    late int discarded;

    setUp(() async {
      api = _Api();
      discarded = 0;
      session = SessionRepository(
        tokenStorage: InMemoryTokenStorage(),
        localStorage: InMemoryLocalStorage(),
      );
      await session.save(token: 'abc', user: AuthUser.fromJson({'id': 7}));
      auth = AuthRepository(
        api: api,
        session: session,
        discardPushToken: () async => discarded++,
      );
    });

    test('is left to the sign-out, which ends the session once', () async {
      bool? handled;
      when(() => api.logout(fcmToken: any(named: 'fcmToken'))).thenAnswer((
        _,
      ) async {
        // What ApiClient does on a 401: call the handler, then throw.
        handled = await auth.expireSession();
        throw const ApiException('Unauthenticated.', status: 401);
      });

      final confirmed = await auth.logout();

      expect(handled, isFalse, reason: 'the 401 handler must not navigate');
      expect(confirmed, isFalse);
      expect(session.isAuthenticated, isFalse);
      expect(discarded, 1, reason: 'the session ends exactly once');
    });

    test('a 401 outside a sign-out still ends the session', () async {
      expect(await auth.expireSession(), isTrue);
      expect(session.isAuthenticated, isFalse);
      expect(await auth.expireSession(), isFalse, reason: 'nothing left');
    });

    test('a sign-out the server confirmed says so', () async {
      when(
        () => api.logout(fcmToken: any(named: 'fcmToken')),
      ).thenAnswer((_) async => <String, dynamic>{});

      expect(await auth.logout(), isTrue);
    });
  });

  // PROF-10. "Keluar" had no guard: a second tap while the first was on its
  // way signed out twice and navigated twice, and "Anda berhasil logout"
  // showed whether or not the server had heard of it.
  group('the profile sign-out', () {
    setUp(() => Get.testMode = true);
    tearDown(Get.reset);

    testWidgets('a second tap while signing out does nothing', (tester) async {
      final auth = _Auth();
      final repo = _Repo();
      when(() => auth.user).thenReturn(AuthUser.fromJson({'id': 7}));
      when(() => repo.attendanceSummary()).thenAnswer(
        (_) async => (points: 0.0, late: 0, attendance: 0, onTime: 0),
      );
      when(() => repo.currentUser()).thenAnswer((_) async => User());
      final answer = Completer<bool>();
      when(() => auth.logout()).thenAnswer((_) => answer.future);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          initialRoute: '/',
          getPages: [
            GetPage(
              name: '/',
              page: () => const Scaffold(body: Text('profil')),
            ),
            GetPage(
              name: AuthRoutes.login,
              page: () => const Scaffold(body: Text('masuk')),
            ),
          ],
        ),
      );

      final controller = Get.put(
        ProfileController(
          repository: repo,
          auth: auth,
          tenantContext: TenantContext(store: InMemorySecureStore()),
        ),
      );

      final first = controller.logout();
      final second = controller.logout();
      expect(controller.isLoggingOut.value, isTrue);

      answer.complete(true);
      await first;
      await second;
      await tester.pumpAndSettle();

      verify(() => auth.logout()).called(1);
      expect(find.text('masuk'), findsOneWidget);
      expect(controller.isLoggingOut.value, isFalse);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    });

    test('says what happened when the server did not hear of it', () {
      expect(
        ProfileController.signedOutMessage(confirmed: true),
        'Anda berhasil logout.',
      );
      expect(
        ProfileController.signedOutMessage(confirmed: false),
        contains('perangkat ini'),
      );
    });
  });
}
