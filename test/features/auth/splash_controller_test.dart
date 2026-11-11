import 'dart:async';

import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/presentation/controllers/splash_controller.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthRepository auth;
  late Completer<SessionState> restore;
  late ServerConfig serverConfig;
  late TenantContext tenantContext;
  late SplashController controller;

  setUp(() async {
    auth = _MockAuthRepository();
    // Never completes, so the controller is caught mid-decision: what is under
    // test is *when* it starts, not what it decides.
    restore = Completer<SessionState>();
    when(() => auth.restoreSession()).thenAnswer((_) => restore.future);

    final store = InMemorySecureStore();
    serverConfig = ServerConfig(store: store);
    tenantContext = TenantContext(store: store);

    await serverConfig.restore();
    await tenantContext.restore();

    // A CONFIGURED handset, which is the precondition for the session check
    // these tests are about. No deployment is compiled into this repository, so
    // an untouched `ServerConfig` has no address and the splash screen would
    // correctly go to setup without ever restoring a session — see the last
    // test in this group, which pins exactly that.
    await serverConfig.save(
      domain: 'https://hrms.example.com',
      subdomainMode: true,
    );
    await tenantContext.remember('acme');

    // GetX refuses contextless navigation without it, and both outcomes below
    // navigate.
    Get.testMode = true;

    controller = SplashController(
      authRepository: auth,
      localStorage: InMemoryLocalStorage(),
      serverConfig: serverConfig,
      tenantContext: tenantContext,
    );
  });

  // The regression this pins: `onInit` runs while `SplashView` is being built,
  // so anything that navigates from it marks the navigator dirty mid-build and
  // Flutter throws. It went unnoticed for as long as every outcome sat behind an
  // `await` — an `async` function runs synchronously only up to its first one —
  // and broke the moment a decision was added that needed no await at all.
  group('when the start destination is resolved', () {
    test('not during onInit, because the view is still building then', () {
      controller.onInit();

      verifyNever(() => auth.restoreSession());
      expect(controller.isLoading.value, isFalse);
    });

    test('but on onReady, which GetX runs after the first frame', () {
      controller.onReady();

      verify(() => auth.restoreSession()).called(1);
      expect(controller.isLoading.value, isTrue);
    });

    test('and a handset with no server asks for one before anything else', () {
      // The ordinary state of a fresh install now that no deployment is
      // compiled in: there is nothing to authenticate *against*, so the session
      // is not probed at all. Asking the server for a token first would be a
      // request with no address to send it to.
      final unconfigured = SplashController(
        authRepository: auth,
        localStorage: InMemoryLocalStorage(),
        serverConfig: ServerConfig(store: InMemorySecureStore()),
        tenantContext: tenantContext,
      );

      unconfigured.onReady();

      verifyNever(() => auth.restoreSession());
    });
  });

  // CORE-04. Opening the app somewhere the server cannot be reached used to
  // end the session and send the person to the login screen. The credential
  // is kept now, and the app opens on what it already has.
  group('where an unreachable server leads', () {
    Future<void> settle(WidgetTester tester, SessionState state) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/start',
          getPages: [
            GetPage(name: '/start', page: () => const Scaffold()),
            GetPage(
              name: HomeRoutes.home,
              page: () => const Scaffold(body: Text('Beranda')),
            ),
            GetPage(
              name: AuthRoutes.login,
              page: () => const Scaffold(body: Text('Halaman masuk')),
            ),
          ],
        ),
      );

      // Stubbed inside the test body: a completer from `setUp` lives outside
      // the widget test's fake-async zone and would never be flushed here.
      when(() => auth.restoreSession()).thenAnswer((_) async => state);

      controller.onReady();
      await tester.pumpAndSettle();
    }

    testWidgets('with a cached user, to the app', (tester) async {
      await settle(tester, SessionState.unverified);

      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Sedang offline'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('with nothing cached, to login with an explanation', (
      tester,
    ) async {
      await settle(tester, SessionState.connectionLost);

      expect(find.text('Halaman masuk'), findsOneWidget);
      expect(Get.arguments, AuthRoutes.connectionLostArgument);
    });
  });
}
