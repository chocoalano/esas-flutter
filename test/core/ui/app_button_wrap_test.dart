import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/components/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX-C32. `AppButton` keeps its label on one line. `wrapLabel` is an opt-in
/// for the few actions whose name must survive a 320dp phone at 200% text;
/// every other button in the app is unchanged.
void main() {
  const label = 'Masukkan Kode Aktivasi Sekarang Juga';

  Future<RenderParagraph> pumpButton(
    WidgetTester tester, {
    required bool wrap,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: AppButton(
                  label: label,
                  icon: Icons.pin_outlined,
                  wrapLabel: wrap,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return tester.renderObject<RenderParagraph>(find.text(label));
  }

  testWidgets('by default the label stays on one line, as before', (
    tester,
  ) async {
    final paragraph = await pumpButton(tester, wrap: false);

    expect(paragraph.maxLines, 1);
    expect(paragraph.overflow, TextOverflow.ellipsis);
    expect(paragraph.didExceedMaxLines, isTrue);
  });

  testWidgets('wrapLabel lets it wrap, and the button keeps 48dp', (
    tester,
  ) async {
    final paragraph = await pumpButton(tester, wrap: true);

    expect(paragraph.maxLines, isNull);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}
