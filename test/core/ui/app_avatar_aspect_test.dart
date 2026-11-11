import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/components/app_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-03. Both `cacheWidth` and `cacheHeight` set means `ResizeImagePolicy.exact`:
/// a 300×400 portrait was decoded at N×N, squashed before `BoxFit.cover` ever
/// saw it.
void main() {
  testWidgets('a photo is decoded keeping its proportions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: AppAvatar(
            imageUrl: 'https://example.com/a.jpg',
            userName: 'Budi Santoso',
            size: 40,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image)).image;

    expect(image, isA<ResizeImage>());
    expect((image as ResizeImage).height, isNull);
    expect(image.width, isNotNull);
  });
}
