import 'package:esas/core/services/device_info_service.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/presentation/controllers/login_controller.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Auth extends Mock implements AuthRepository {}

class _Device extends Mock implements DeviceInfoService {}

void main() {
  tearDown(Get.reset);

  testWidgets(
    'logout for connection loss opens login with the required internet alert',
    (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(),
          getPages: [
            GetPage(
              name: AuthRoutes.login,
              page: () => const Scaffold(body: Text('Halaman masuk')),
              binding: BindingsBuilder(() {
                Get.put(
                  LoginController(
                    authRepository: _Auth(),
                    deviceInfo: _Device(),
                  ),
                );
              }),
            ),
          ],
        ),
      );

      Get.offAllNamed(
        AuthRoutes.login,
        arguments: AuthRoutes.connectionLostArgument,
      );
      await tester.pumpAndSettle();

      expect(find.text('Halaman masuk'), findsOneWidget);
      expect(find.text('Koneksi internet diperlukan'), findsOneWidget);
      expect(find.textContaining('Anda otomatis keluar'), findsOneWidget);
      expect(
        find.textContaining('wajib terhubung ke internet'),
        findsOneWidget,
      );
      await tester.tap(find.text('Mengerti'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
