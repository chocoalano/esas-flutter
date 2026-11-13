import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads Roboto — what Android draws this app's theme with — from the Flutter
/// SDK's own cache. Returns false when the SDK has no copy.
///
/// The test font draws every glyph a full em wide, about twice Roboto, so it
/// cannot say whether a label fits on a phone; [cutShort] needs a real font.
Future<bool> loadRoboto() async {
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final loader = FontLoader('Roboto');
  var found = 0;

  for (final weight in const ['Regular', 'Medium', 'Bold']) {
    final file = File('${artifacts.path}/material_fonts/Roboto-$weight.ttf');

    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      found++;
    }
  }

  if (found == 0) return false;

  await loader.load();
  return true;
}

/// Every single-line text a real font would cut short: each one-line text in
/// the tree is measured again with Roboto, in its own style, at its own text
/// scale, against the width it was actually given.
List<String> cutShort(WidgetTester tester) {
  final cut = <String>[];

  for (final paragraph
      in tester.allRenderObjects.whereType<RenderParagraph>()) {
    final singleLine = paragraph.maxLines ?? (paragraph.softWrap ? null : 1);

    if (singleLine == null) continue;

    final painter = TextPainter(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'Roboto'),
        children: [paragraph.text],
      ),
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      maxLines: singleLine,
    )..layout(maxWidth: paragraph.constraints.maxWidth);

    if (painter.didExceedMaxLines) cut.add(paragraph.text.toPlainText());
    painter.dispose();
  }

  return cut;
}
