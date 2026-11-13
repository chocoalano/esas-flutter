import 'dart:async';
import 'dart:io';

import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/attendance/presentation/widgets/attendance_device_gate.dart';
import 'package:esas/features/auth/data/models/device_status.dart';
import 'package:esas/features/auth/data/repositories/device_proof_gate.dart';
import 'package:esas/features/auth/data/repositories/device_proof_repository.dart';
import 'package:esas/features/auth/presentation/controllers/device_enrollment_controller.dart';
import 'package:esas/features/auth/presentation/routes/device_routes.dart';
import 'package:esas/features/auth/presentation/views/device_enrollment_view.dart';
import 'package:esas/features/auth/presentation/widgets/device_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements DeviceProofRepository {}

class _MockGate extends Mock implements DeviceProofGate {}

/// The device screens on the narrowest phone this app supports (320dp) with
/// the system text size turned up to 200%. A RenderFlex overflow is reported
/// by the framework as an exception, so "no exception" is one assertion; the
/// other is that no text was cut short with an ellipsis — an action whose name
/// is cut off is an action nobody can be sure of.
void main() {
  const scales = <double>[1.0, 1.5, 2.0];
  const narrow = Size(320, 640);

  const device = DeviceStatus(
    proofRequired: true,
    enrollmentAvailable: true,
    keyEnrolled: true,
    keyFingerprint: 'IlfYwWq-JnSBK58YUV9Gn79JLLxxXt8uVrs1RWXf0UI',
  );

  /// Every single-line text that a real font would cut short.
  ///
  /// The widget tree is laid out with the test font, which draws every glyph
  /// a full em wide — about twice Roboto — and so "truncates" text that fits
  /// on a phone. Each one-line text is therefore measured again with Roboto
  /// (what Android draws this theme with), in its own style, at its own text
  /// scale, against the width it was actually given.
  List<String> truncated(WidgetTester tester) {
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

  // The test font draws every glyph a full em wide, about twice a real font,
  // which would call text "truncated" that fits on a phone. Roboto — what
  // Android renders this theme with — ships in the Flutter SDK's cache.
  var realFont = false;

  setUpAll(() async {
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

    if (found > 0) {
      await loader.load();
      realFont = true;
    }
  });

  setUpAll(
    () =>
        registerFallbackValue(const DeviceGateDecision(DeviceGateStatus.ready)),
  );

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  void useNarrowScreen(WidgetTester tester) {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget scaled(double scale, Widget child) => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    ),
  );

  group('status card', () {
    for (final status in DeviceGateStatus.values) {
      for (final scale in scales) {
        testWidgets('${status.name} @320dp x$scale', (tester) async {
          useNarrowScreen(tester);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: scaled(
                scale,
                Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: DeviceStatusCard(
                      status: status,
                      device: device,
                      busy: status == DeviceGateStatus.needsProof,
                      onEnterCode: () {},
                      onRetry: () {},
                      onContinue: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          if (realFont) expect(truncated(tester), isEmpty);
        });
      }
    }
  });

  group('attendance gate, blocked', () {
    for (final scale in scales) {
      testWidgets('recovery @320dp x$scale', (tester) async {
        useNarrowScreen(tester);
        final gate = _MockGate();
        when(() => gate.confirmKeystore(any())).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as DeviceGateDecision,
        );
        when(() => gate.device).thenReturn(device);
        when(() => gate.evaluate()).thenReturn(
          const DeviceGateDecision(DeviceGateStatus.recovery, device: device),
        );

        await tester.pumpWidget(
          GetMaterialApp(
            theme: AppTheme.lightTheme,
            home: scaled(
              scale,
              AttendanceDeviceGate(gate: gate, child: const SizedBox()),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        if (realFont) expect(truncated(tester), isEmpty);
        expect(
          find.text('Hubungi HR untuk Mengganti Perangkat'),
          findsOneWidget,
        );
      });
    }
  });

  group('enrolment screen', () {
    final stagesFor = <String, Future<void> Function(_MockRepository)>{
      'input': (repository) async {},
      'invalid code': (repository) async => when(
        () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
      ).thenThrow(const DeviceProofException(DeviceProofFailure.invalidCode)),
      'offline': (repository) async => when(
        () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
      ).thenThrow(const DeviceProofException(DeviceProofFailure.offline)),
      'failed': (repository) async => when(
        () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
      ).thenThrow(const DeviceProofException(DeviceProofFailure.rateLimited)),
      'key unavailable': (repository) async =>
          when(
            () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
          ).thenThrow(
            const DeviceProofException(DeviceProofFailure.keyUnavailable),
          ),
      'recovery': (repository) async => when(
        () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
      ).thenThrow(const DeviceProofException(DeviceProofFailure.proofInvalid)),
      'session ended': (repository) async => when(
        () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
      ).thenThrow(const DeviceProofException(DeviceProofFailure.sessionEnded)),
      'success': (repository) async => when(
        () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
      ).thenAnswer((_) async => device),
    };

    for (final entry in stagesFor.entries) {
      for (final scale in scales) {
        testWidgets('${entry.key} @320dp x$scale', (tester) async {
          useNarrowScreen(tester);
          final repository = _MockRepository();
          when(() => repository.current).thenReturn(device);
          await entry.value(repository);

          await tester.pumpWidget(
            GetMaterialApp(
              theme: AppTheme.lightTheme,
              initialRoute: DeviceRoutes.enrollment,
              builder: (context, child) => scaled(scale, child!),
              getPages: [
                GetPage(
                  name: DeviceRoutes.enrollment,
                  page: () => const DeviceEnrollmentView(),
                  binding: BindingsBuilder(() {
                    Get.put(
                      DeviceEnrollmentController(
                        repository: repository,
                        onSessionEnded: () async {},
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          if (entry.key != 'input') {
            await tester.enterText(
              find.byKey(const ValueKey('enrollment-code-field')),
              'ABCDE12345',
            );
            await tester.pump();
            unawaited(Get.find<DeviceEnrollmentController>().submit());
            await tester.pumpAndSettle();
          }

          expect(tester.takeException(), isNull);
          if (realFont) expect(truncated(tester), isEmpty);
        });
      }
    }
  });
}
