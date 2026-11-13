import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/services/device_info_service.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/components/app_button.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/presentation/controllers/login_controller.dart';
import 'package:esas/features/auth/presentation/routes/auth_pages.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/setup/presentation/routes/setup_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockDeviceInfo extends Mock implements DeviceInfoService {}

/// UX-C34. The NIP typed in the password-reset sheet came back to an empty
/// sign-in form and had to be typed again (measured in journey J3). It now
/// returns through `LoginController.requestPasswordReset` — the callback the
/// sheet already calls — with no edit to `login_view.dart`.
///
/// Guarded here: only the person's own input returns, only after the server
/// accepted the request, the password is never touched, and the value cannot
/// follow the person into another workspace.
void main() {
  late _MockAuth auth;

  const generic =
      'Jika akun terdaftar, instruksi reset kata sandi telah dikirim ke '
      'email terdaftar.';

  setUp(() {
    Get.testMode = true;
    auth = _MockAuth();
    final device = _MockDeviceInfo();
    when(() => auth.canSignInWithGoogle).thenReturn(false);
    when(() => auth.canSignInWithApple).thenReturn(false);
    when(() => auth.isAuthenticated).thenReturn(false);
    when(() => device.deviceId()).thenAnswer((_) async => 'dev-1');
    when(() => device.legacyDeviceId()).thenAnswer((_) async => null);
    Get.put<AuthRepository>(auth);
    Get.put<DeviceInfoService>(device);
  });

  tearDown(Get.reset);

  /// The production login page and binding, plus the last step of
  /// `SetupController.proceed` — `Get.offAllNamed(AuthRoutes.login)` — which
  /// is how a workspace switch returns to signing in.
  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: AuthRoutes.login,
        getPages: [
          ...AuthPages.pages.where((page) => page.name == AuthRoutes.login),
          GetPage(
            name: SetupRoutes.setup,
            page: () => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Get.offAllNamed(AuthRoutes.login),
                  child: const Text('Gunakan workspace ini'),
                ),
              ),
            ),
            binding: BindingsBuilder(() {}),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  String textOf(WidgetTester tester, String hint) =>
      tester.widget<TextFormField>(field(hint)).controller!.text;

  Future<void> resetVia(WidgetTester tester, String identifier) async {
    await tester.tap(find.text('Lupa kata sandi?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      field('Contoh: 12345678 atau nama@perusahaan.com'),
      identifier,
    );
    final submit = find.byWidgetPredicate(
      (w) => w is AppButton && w.label == 'Kirim Instruksi Reset',
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  Future<void> backToLogin(WidgetTester tester) async {
    final back = find.byWidgetPredicate(
      (w) => w is AppButton && w.label == 'Kembali ke Halaman Masuk',
    );
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();
  }

  testWidgets('the NIP typed in the reset sheet is waiting in the sign-in '
      'form, and the password field is untouched', (tester) async {
    when(
      () => auth.requestPasswordReset(identifier: any(named: 'identifier')),
    ).thenAnswer((_) async => generic);
    await pumpLogin(tester);

    await resetVia(tester, ' 20240113 ');
    expect(find.text(generic), findsOneWidget);
    await backToLogin(tester);

    expect(textOf(tester, 'NIP atau nama@perusahaan.com'), '20240113');
    expect(textOf(tester, 'Masukkan kata sandi'), isEmpty);
    verify(() => auth.requestPasswordReset(identifier: '20240113')).called(1);
  });

  testWidgets('a request the server did not accept carries nothing back', (
    tester,
  ) async {
    when(
      () => auth.requestPasswordReset(identifier: any(named: 'identifier')),
    ).thenThrow(
      const ApiException(
        'Tidak ada koneksi internet. Periksa jaringan Anda.',
        code: 'network_unreachable',
      ),
    );
    await pumpLogin(tester);

    await resetVia(tester, '20240113');
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'NIP atau nama@perusahaan.com'), isEmpty);
  });

  testWidgets('a workspace switch leaves an empty sign-in form and a new '
      'controller', (tester) async {
    when(
      () => auth.requestPasswordReset(identifier: any(named: 'identifier')),
    ).thenAnswer((_) async => generic);
    await pumpLogin(tester);

    await resetVia(tester, '20240113');
    await backToLogin(tester);
    final before = Get.find<LoginController>();
    expect(before.nipController.text, '20240113');

    await tester.tap(find.text('Ganti workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gunakan workspace ini'));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'NIP atau nama@perusahaan.com'), isEmpty);
    expect(identical(Get.find<LoginController>(), before), isFalse);
  });
}
