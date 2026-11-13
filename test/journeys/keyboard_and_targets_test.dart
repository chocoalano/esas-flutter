import 'package:esas/core/services/device_info_service.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/data/repositories/device_proof_repository.dart';
import 'package:esas/features/auth/presentation/controllers/device_enrollment_controller.dart';
import 'package:esas/features/auth/presentation/controllers/login_controller.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/auth/presentation/routes/device_routes.dart';
import 'package:esas/features/auth/presentation/views/device_enrollment_view.dart';
import 'package:esas/features/auth/presentation/views/login_view.dart';
import 'package:esas/features/auth/presentation/widgets/forgot_password_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockDeviceRepository extends Mock implements DeviceProofRepository {}

class _MockAuth extends Mock implements AuthRepository {}

class _MockDeviceInfo extends Mock implements DeviceInfoService {}

/// AUTOMATED, NOT DEVICE UAT. The smallest phone the app supports (320×568)
/// with the on-screen keyboard up (260dp of view inset): every field a person
/// types into must stay above the keyboard, and the action after it must be
/// reachable by scrolling. Plus the login screen's tap targets.
void main() {
  const screen = Size(320, 568);
  const keyboard = 260.0;

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> raiseKeyboard(WidgetTester tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// Fully inside what is left of the screen above the keyboard.
  void expectAboveKeyboard(WidgetTester tester, Finder finder, String what) {
    final rect = tester.getRect(finder);

    expect(rect.top, greaterThanOrEqualTo(0), reason: '$what is off the top');
    expect(
      rect.bottom,
      lessThanOrEqualTo(screen.height - keyboard),
      reason: '$what is under the keyboard (bottom ${rect.bottom})',
    );
  }

  testWidgets('code screen: the field stays above the keyboard, and '
      '"Daftarkan Perangkat" can be scrolled to', (tester) async {
    phone(tester);
    final repository = _MockDeviceRepository();
    when(() => repository.current).thenReturn(null);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: DeviceRoutes.enrollment,
        getPages: [
          GetPage(
            name: DeviceRoutes.enrollment,
            page: () => const DeviceEnrollmentView(),
            binding: BindingsBuilder(() {
              Get.put(DeviceEnrollmentController(repository: repository));
            }),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('enrollment-code-field'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await raiseKeyboard(tester);
    await tester.enterText(field, 'ABCDE12345');
    await tester.pumpAndSettle();

    expectAboveKeyboard(tester, find.byType(EditableText), 'the code field');

    final submit = find.text('Daftarkan Perangkat');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expectAboveKeyboard(tester, submit, '"Daftarkan Perangkat"');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset sheet: the NIP field stays above the keyboard', (
    tester,
  ) async {
    phone(tester);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showForgotPasswordSheet(
                  context,
                  selfServiceAvailable: true,
                  onSubmit: (_) async => 'ok',
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    final field = find.byType(EditableText);
    await tester.tap(field);
    await raiseKeyboard(tester);

    expectAboveKeyboard(tester, field, 'the NIP field');

    final submit = find.text('Kirim Instruksi Reset');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expectAboveKeyboard(tester, submit, '"Kirim Instruksi Reset"');
    expect(tester.takeException(), isNull);
  });

  group('login screen', () {
    Future<void> pumpLogin(WidgetTester tester) async {
      phone(tester);
      final auth = _MockAuth();
      final device = _MockDeviceInfo();
      when(() => auth.canSignInWithGoogle).thenReturn(false);
      when(() => auth.canSignInWithApple).thenReturn(false);
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
                Get.put(
                  LoginController(authRepository: auth, deviceInfo: device),
                );
              }),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the password field stays above the keyboard', (tester) async {
      await pumpLogin(tester);

      final password = find.byType(EditableText).at(1);
      await tester.ensureVisible(password);
      await tester.tap(password);
      await raiseKeyboard(tester);

      expectAboveKeyboard(tester, password, 'the password field');
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Lupa kata sandi?" is a full-size tap target', (tester) async {
      await pumpLogin(tester);

      final link = find.ancestor(
        of: find.text('Lupa kata sandi?'),
        matching: find.byType(TextButton),
      );
      final size = tester.getSize(link);

      // ignore: avoid_print
      print(
        'TARGET | "Lupa kata sandi?" | ${size.width.toStringAsFixed(0)}x'
        '${size.height.toStringAsFixed(0)}dp',
      );
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
