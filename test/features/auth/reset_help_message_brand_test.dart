import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/presentation/widgets/forgot_password_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// PO Putaran 10, Slice B: the message an employee copies for HR / IT names
/// the app the way every other screen does ("Absensas"), not by the internal
/// project name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  testWidgets('the copied HR message names Absensas, not ESAS', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ForgotPasswordSheet(
            initialIdentifier: 'EMP001',
            onSubmit: (_) async => '',
          ),
        ),
      ),
    );
    await tester.pump();

    final copy = find.text('Salin Format Permintaan ke HR');
    await tester.ensureVisible(copy);
    await tester.pump();
    await tester.tap(copy);
    await tester.pump();

    expect(copied, isNotNull);
    expect(copied, contains('akun Absensas'));
    expect(copied, isNot(contains('ESAS')));
    expect(copied, contains('NIP/Email: EMP001'));

    // Let the confirmation snackbar's timer run out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
