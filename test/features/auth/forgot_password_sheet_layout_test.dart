import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/presentation/widgets/forgot_password_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'text_fit_helper.dart';

/// The password-reset sheet on the narrowest phone (320dp) with the system
/// text size raised to 200%, and with a screen reader's eyes: Flutter's own
/// guidelines for tap-target size, labelled targets and contrast.
void main() {
  var realFont = false;

  setUpAll(() async => realFont = await loadRoboto());
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<void> pumpSheet(
    WidgetTester tester, {
    double scale = 1.0,
    bool submitted = false,
  }) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: ForgotPasswordSheet(
                initialIdentifier: '20240113',
                selfServiceAvailable: true,
                onSubmit: (_) async =>
                    'Bila akun terdaftar, instruksi telah dikirim.',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    if (submitted) {
      await tester.ensureVisible(find.text('Kirim Instruksi Reset'));
      await tester.tap(find.text('Kirim Instruksi Reset'));
      await tester.pumpAndSettle();
    }
  }

  for (final submitted in [false, true]) {
    final state = submitted ? 'sent' : 'form';

    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('$state @320dp x$scale: no overflow, nothing cut short', (
        tester,
      ) async {
        await pumpSheet(tester, scale: scale, submitted: submitted);

        expect(tester.takeException(), isNull);
        if (realFont) expect(cutShort(tester), isEmpty);
      });
    }

    testWidgets('$state: tap targets and screen-reader labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSheet(tester, submitted: submitted);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
