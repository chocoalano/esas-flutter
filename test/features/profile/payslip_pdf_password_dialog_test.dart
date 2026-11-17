import 'package:esas/features/profile/presentation/views/payslip_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the payslip PDF password is shown once, readable, and copied on request '
    '(WP-01 Final, G6)',
    (tester) async {
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPayslipPdfPassword('Kp7mQx2RtV9wLz4N'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Kata sandi slip gaji'), findsOneWidget);
      expect(find.text('Kp7mQx2RtV9wLz4N'), findsOneWidget);
      expect(
        find.textContaining('tidak akan ditampilkan lagi'),
        findsOneWidget,
      );

      await tester.tap(find.text('Salin & tutup'));
      await tester.pumpAndSettle();

      expect(copied, 'Kp7mQx2RtV9wLz4N');
      expect(find.text('Kata sandi slip gaji'), findsNothing);
    },
  );
}
