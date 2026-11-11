import 'dart:async';

import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/data/services/auth_api_service.dart';
import 'package:esas/features/auth/presentation/controllers/change_password_controller.dart';
import 'package:esas/features/auth/presentation/views/change_password_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements AuthApiService {}

/// AUTH-01. `PUT /auth/password` answers 200 with `{message,
/// other_devices_signed_out}` — there is no `success` key. Errors arrive as
/// exceptions. The screen used to read a missing `success` as failure: the
/// password HAD changed, every other device had been signed out, and the
/// person was told "Gagal" and left with a form that still held the old one.
void main() {
  late _Api api;
  late ChangePasswordController controller;

  setUp(() {
    Get.testMode = true;
    api = _Api();
    controller = ChangePasswordController(api: api);
    Get.put(controller);
  });

  tearDown(Get.reset);

  Future<void> fillIn(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        home: const ChangePasswordView(),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'lama-12345');
    await tester.enterText(fields.at(1), 'baru-12345');
    await tester.enterText(fields.at(2), 'baru-12345');
  }

  void answer(Future<Map<String, dynamic>> Function() reply) {
    when(
      () => api.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
        confirmation: any(named: 'confirmation'),
      ),
    ).thenAnswer((_) => reply());
  }

  testWidgets('the server\'s real success reply is shown as success', (
    tester,
  ) async {
    answer(
      () async => {
        'message': 'Kata sandi berhasil diubah.',
        'other_devices_signed_out': 2,
      },
    );
    await fillIn(tester);

    await controller.changePassword();
    await tester.pump();

    expect(find.text('Gagal'), findsNothing);
    expect(find.text('Kata sandi berhasil diubah.'), findsOneWidget);
    expect(controller.currentPasswordController.text, isEmpty);
    expect(controller.newPasswordController.text, isEmpty);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a second submit while the first is in flight sends nothing', (
    tester,
  ) async {
    final reply = Completer<Map<String, dynamic>>();
    answer(() => reply.future);
    await fillIn(tester);

    unawaited(controller.changePassword());
    unawaited(controller.changePassword());
    await tester.pump();

    verify(
      () => api.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
        confirmation: any(named: 'confirmation'),
      ),
    ).called(1);

    reply.complete({'message': 'Kata sandi berhasil diubah.'});
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
