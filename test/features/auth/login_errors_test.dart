import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/services/device_info_service.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/presentation/controllers/login_controller.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Auth extends Mock implements AuthRepository {}

class _Device extends Mock implements DeviceInfoService {}

void main() {
  late _Auth auth;
  late LoginController controller;

  setUp(() {
    Get.testMode = true;
    auth = _Auth();
    final device = _Device();
    when(() => device.deviceId()).thenAnswer((_) async => 'android-id');
    when(() => device.legacyDeviceId()).thenAnswer((_) async => null);
    when(() => auth.isAuthenticated).thenReturn(false);
    controller = LoginController(authRepository: auth, deviceInfo: device);
    Get.put(controller);
  });

  tearDown(Get.reset);

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(),
      getPages: [
        GetPage(name: HomeRoutes.home, page: () => const Scaffold()),
      ],
    ),
  );

  void refuseWith(ApiException error) {
    when(
      () => auth.login(
        identifier: any(named: 'identifier'),
        password: any(named: 'password'),
        deviceId: any(named: 'deviceId'),
        legacyDeviceId: any(named: 'legacyDeviceId'),
      ),
    ).thenThrow(error);
  }

  Future<void> signIn(WidgetTester tester) async {
    controller.nipController.text = '20240113';
    controller.passwordController.text = 'salah';
    await controller.loginUser();
    await tester.pump();
  }

  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  // AUTH-04. The login endpoint never answers 401: wrong credentials are a 422
  // on `identifier` carrying Laravel's untranslated "These credentials do not
  // match our records.", and the limiter answers 429 "Too Many Attempts.".
  group('a refused sign-in is explained in Indonesian', () {
    testWidgets('wrong credentials (422)', (tester) async {
      await pumpApp(tester);
      refuseWith(
        const ApiException(
          'These credentials do not match our records.',
          status: 422,
          errors: {'identifier': 'These credentials do not match our records.'},
        ),
      );

      await signIn(tester);

      expect(find.textContaining('These credentials'), findsNothing);
      expect(
        find.text('NIP/Email atau kata sandi salah. Silakan coba lagi.'),
        findsOneWidget,
      );
      await drain(tester);
    });

    testWidgets('too many attempts (429)', (tester) async {
      await pumpApp(tester);
      refuseWith(const ApiException('Too Many Attempts.', status: 429));

      await signIn(tester);

      expect(find.textContaining('Too Many'), findsNothing);
      expect(find.textContaining('Terlalu banyak percobaan'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('a refusal the server already words is kept', (tester) async {
      await pumpApp(tester);
      refuseWith(
        const ApiException(
          'Akun ini tidak lagi aktif.',
          status: 422,
          errors: {'identifier': 'Akun ini tidak lagi aktif.'},
        ),
      );

      await signIn(tester);

      expect(find.text('Akun ini tidak lagi aktif.'), findsOneWidget);
      await drain(tester);
    });
  });

  // AUTH-05. Laravel's TrimStrings middleware leaves `password` alone, and so
  // does the change-password screen. Trimming here made a password ending in a
  // space impossible to sign in with.
  testWidgets('the password is sent exactly as typed', (tester) async {
    await pumpApp(tester);
    when(
      () => auth.login(
        identifier: any(named: 'identifier'),
        password: any(named: 'password'),
        deviceId: any(named: 'deviceId'),
        legacyDeviceId: any(named: 'legacyDeviceId'),
      ),
    ).thenAnswer((_) async => AuthUser.fromJson({'id': 7}));

    controller.nipController.text = ' 20240113 ';
    controller.passwordController.text = ' Rahasia123 ';
    await controller.loginUser();
    await tester.pumpAndSettle();

    verify(
      () => auth.login(
        identifier: '20240113',
        password: ' Rahasia123 ',
        deviceId: 'android-id',
        legacyDeviceId: null,
      ),
    ).called(1);
    await drain(tester);
  });
}
