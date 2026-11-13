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
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements DeviceProofRepository {}

class _MockGate extends Mock implements DeviceProofGate {}

/// Flutter's own accessibility guidelines on the device screens: every tap
/// target at least 48dp (Android) / 44pt (iOS), every tap target named for a
/// screen reader, and text that meets WCAG AA contrast.
void main() {
  const device = DeviceStatus(
    proofRequired: true,
    enrollmentAvailable: true,
    keyEnrolled: true,
    keyFingerprint: 'IlfYwWq-JnSBK58YUV9Gn79JLLxxXt8uVrs1RWXf0UI',
  );

  setUpAll(
    () =>
        registerFallbackValue(const DeviceGateDecision(DeviceGateStatus.ready)),
  );

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<void> expectGuidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  for (final status in DeviceGateStatus.values) {
    testWidgets('status card ${status.name}', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
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
      );

      await expectGuidelines(tester);
      handle.dispose();
    });
  }

  testWidgets('attendance gate, blocked', (tester) async {
    final handle = tester.ensureSemantics();
    final gate = _MockGate();
    when(() => gate.confirmKeystore(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.first as DeviceGateDecision,
    );
    when(() => gate.device).thenReturn(device);
    when(() => gate.evaluate()).thenReturn(
      const DeviceGateDecision(DeviceGateStatus.notEnrolled, device: device),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        home: AttendanceDeviceGate(gate: gate, child: const SizedBox()),
      ),
    );
    await tester.pump();

    await expectGuidelines(tester);
    handle.dispose();
  });

  final outcomes = <String, DeviceProofException?>{
    'input': null,
    'invalid code': const DeviceProofException(DeviceProofFailure.invalidCode),
    'offline': const DeviceProofException(DeviceProofFailure.offline),
    'recovery': const DeviceProofException(DeviceProofFailure.proofInvalid),
    'session ended': const DeviceProofException(
      DeviceProofFailure.sessionEnded,
    ),
  };

  for (final entry in outcomes.entries) {
    testWidgets('enrolment screen ${entry.key}', (tester) async {
      final handle = tester.ensureSemantics();
      final repository = _MockRepository();
      when(() => repository.current).thenReturn(device);
      if (entry.value != null) {
        when(
          () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
        ).thenThrow(entry.value!);
      }

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          initialRoute: DeviceRoutes.enrollment,
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

      if (entry.value != null) {
        await tester.enterText(
          find.byKey(const ValueKey('enrollment-code-field')),
          'ABCDE12345',
        );
        await tester.pump();
        await Get.find<DeviceEnrollmentController>().submit();
        await tester.pumpAndSettle();
      }

      await expectGuidelines(tester);
      handle.dispose();
    });
  }
}
