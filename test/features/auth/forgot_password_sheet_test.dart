import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/services/device_info_service.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/presentation/controllers/login_controller.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/auth/presentation/views/login_view.dart';
import 'package:esas/features/auth/presentation/widgets/forgot_password_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockDevice extends Mock implements DeviceInfoService {}

void main() {
  late _MockAuth auth;
  late _MockDevice device;

  setUp(() {
    Get.testMode = true;
    auth = _MockAuth();
    device = _MockDevice();
    when(() => auth.canSignInWithGoogle).thenReturn(false);
    when(() => auth.canSignInWithApple).thenReturn(false);
    when(() => auth.isAuthenticated).thenReturn(false);
    when(() => device.deviceId()).thenAnswer((_) async => 'dev-1');
    when(() => device.legacyDeviceId()).thenAnswer((_) async => null);
  });

  tearDown(Get.reset);

  Widget createTestWidget() {
    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      initialRoute: AuthRoutes.login,
      getPages: [
        GetPage(
          name: AuthRoutes.login,
          page: () => const LoginView(),
          binding: BindingsBuilder(() {
            Get.put(LoginController(authRepository: auth, deviceInfo: device));
          }),
        ),
      ],
    );
  }

  testWidgets('renders "Lupa kata sandi?" button on LoginView', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Lupa kata sandi?'), findsOneWidget);
  });

  testWidgets('tapping "Lupa kata sandi?" opens ForgotPasswordSheet with prefilled NIP',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Type NIP first
    final nipFinder = find.byType(TextFormField).first;
    await tester.enterText(nipFinder, '19950123');
    await tester.pump();

    // Tap "Lupa kata sandi?"
    await tester.tap(find.text('Lupa kata sandi?'));
    await tester.pumpAndSettle();

    // Verify sheet is open
    expect(find.byType(ForgotPasswordSheet), findsOneWidget);
    expect(find.text('Lupa Kata Sandi?'), findsOneWidget);
    expect(find.text('19950123'), findsWidgets);
  });

  // The self-service submit, for when the server offers it. Login does not
  // today (FUNC-C01), so these open the sheet directly with the flag on.
  Future<void> pumpSelfServiceSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForgotPasswordSheet(
              selfServiceAvailable: true,
              onSubmit: (identifier) =>
                  auth.requestPasswordReset(identifier: identifier),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('submitting valid identifier shows success screen',
      (tester) async {
    when(
      () => auth.requestPasswordReset(identifier: '19950123'),
    ).thenAnswer((_) async => 'Instruksi pemulihan telah dikirim ke email.');

    await pumpSelfServiceSheet(tester);

    await tester.enterText(find.byType(TextFormField), '19950123');
    await tester.tap(find.text('Kirim Instruksi Reset'));
    await tester.pumpAndSettle();

    // Verify success view
    expect(find.text('Permintaan Terkirim'), findsOneWidget);
    expect(
      find.text('Instruksi pemulihan telah dikirim ke email.'),
      findsOneWidget,
    );
    expect(find.text('Kembali ke Halaman Masuk'), findsOneWidget);
  });

  testWidgets('shows error banner when API throws ApiException',
      (tester) async {
    when(
      () => auth.requestPasswordReset(identifier: 'wrong@example.com'),
    ).thenThrow(const ApiException('Email tidak ditemukan.', status: 404));

    await pumpSelfServiceSheet(tester);

    await tester.enterText(find.byType(TextFormField), 'wrong@example.com');
    await tester.tap(find.text('Kirim Instruksi Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Email tidak ditemukan.'), findsOneWidget);
    expect(find.text('Permintaan Terkirim'), findsNothing);
  });

  testWidgets('shows validation error when identifier is empty',
      (tester) async {
    await pumpSelfServiceSheet(tester);

    // Tap submit button with empty input
    await tester.tap(find.text('Kirim Instruksi Reset'));
    await tester.pumpAndSettle();

    expect(find.text('NIP atau Email tidak boleh kosong'), findsOneWidget);
    expect(find.text('Permintaan Terkirim'), findsNothing);
  });

  testWidgets(
      'FUNC-C01 / PO 4.3: from login the sheet offers the reset link and still points to HR',
      (tester) async {
    when(
      () => auth.requestPasswordReset(identifier: 'EMP-07A'),
    ).thenAnswer(
      (_) async =>
          'Jika akun terdaftar dan emailnya sudah terverifikasi, tautan untuk mengatur ulang kata sandi telah dikirim. Bila tidak menerima email dalam beberapa menit, hubungi HR.',
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'EMP-07A');
    await tester.tap(find.text('Lupa kata sandi?'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordSheet), findsOneWidget);
    expect(find.text('Salin Format Permintaan ke HR'), findsOneWidget);

    await tester.ensureVisible(find.text('Kirim Instruksi Reset'));
    await tester.tap(find.text('Kirim Instruksi Reset'));
    await tester.pumpAndSettle();

    verify(() => auth.requestPasswordReset(identifier: 'EMP-07A')).called(1);
    // The answer never says whether the account exists.
    expect(find.textContaining('Jika akun terdaftar'), findsOneWidget);
  });

  testWidgets('FUNC-C03: the sign-in field takes a NIP with letters or an email',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('NIP atau email'), findsOneWidget);

    final field = find.byType(TextFormField).first;
    await tester.enterText(field, 'EMP-07A');
    await tester.pump();
    expect(find.text('EMP-07A'), findsOneWidget);

    await tester.enterText(field, 'budi@perusahaan.co.id');
    await tester.pump();
    expect(find.text('budi@perusahaan.co.id'), findsOneWidget);
  });

  testWidgets('tapping "Salin Format Permintaan ke HR" works', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lupa kata sandi?'));
    await tester.pumpAndSettle();

    expect(find.text('Salin Format Permintaan ke HR'), findsOneWidget);
    await tester.tap(find.text('Salin Format Permintaan ke HR'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
