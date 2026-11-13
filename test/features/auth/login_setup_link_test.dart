import 'package:esas/core/services/device_info_service.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/presentation/controllers/login_controller.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/auth/presentation/views/login_view.dart';
import 'package:esas/features/setup/presentation/routes/setup_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Auth extends Mock implements AuthRepository {}

class _Device extends Mock implements DeviceInfoService {}

/// SETUP-01. A handset set up against the wrong workspace had no way back from
/// the login screen: setup opened only while no workspace was stored, and
/// "Pindah Workspace" sat behind a sign-in to the wrong company.
void main() {
  tearDown(Get.reset);

  testWidgets('the login screen leads back to setup', (tester) async {
    Get.testMode = true;
    final auth = _Auth();
    when(() => auth.canSignInWithGoogle).thenReturn(false);
    when(() => auth.isAuthenticated).thenReturn(false);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: AuthRoutes.login,
        getPages: [
          GetPage(
            name: AuthRoutes.login,
            page: () => const LoginView(),
            binding: BindingsBuilder(() {
              Get.put(LoginController(authRepository: auth, deviceInfo: _Device()));
            }),
          ),
          GetPage(
            name: SetupRoutes.setup,
            page: () => const Scaffold(body: Text('Halaman setup')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Ganti workspace'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ganti workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Halaman setup'), findsOneWidget);
  });

  testWidgets('renders Google sign-in button with logo when enabled',
      (tester) async {
    Get.testMode = true;
    final auth = _Auth();
    when(() => auth.canSignInWithGoogle).thenReturn(true);
    when(() => auth.isAuthenticated).thenReturn(false);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: AuthRoutes.login,
        getPages: [
          GetPage(
            name: AuthRoutes.login,
            page: () => const LoginView(),
            binding: BindingsBuilder(() {
              Get.put(LoginController(
                authRepository: auth,
                deviceInfo: _Device(),
              ));
            }),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masuk dengan Google'), findsOneWidget);
  });
}
