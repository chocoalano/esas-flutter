import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/services/camera_permission_service.dart';
import 'package:esas/core/services/location_service.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/attendance/data/models/attendance_context.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:esas/features/attendance/presentation/views/attendance_list_view.dart';
import 'package:esas/features/attendance/presentation/views/attendance_view.dart';
import 'package:esas/features/attendance/presentation/widgets/attendance_device_gate.dart';
import 'package:esas/features/auth/data/models/device_status.dart';
import 'package:esas/features/auth/data/repositories/device_proof_gate.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';

class _MockGate extends Mock implements DeviceProofGate {}

class _MockRepository extends Mock implements AttendanceRepository {}

class _MockLocation extends Mock implements LocationService {}

class _MockSession extends Mock implements SessionRepository {}

class _MockStorage extends Mock implements LocalStorage {}

class _MockPermission extends Mock implements CameraPermissionService {}

class _FakeScanner extends ValueNotifier<MobileScannerState>
    implements MobileScannerController {
  _FakeScanner() : super(const MobileScannerState.uninitialized());

  @override
  Future<void> start({CameraFacing? cameraDirection}) async {
    value = value.copyWith(isInitialized: true, isRunning: true);
  }

  @override
  Future<void> stop() async => value = value.copyWith(isRunning: false);

  @override
  Future<void> pause() async => value = value.copyWith(isRunning: false);

  @override
  Future<void> dispose() async => super.dispose();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// ADR-D §9 (c): the gate sits at the attendance ENTRY — a route middleware on
/// `/attendance` — and never inside Face capture or liveness.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockGate gate;

  const enrollmentOpen = DeviceStatus(
    proofRequired: true,
    enrollmentAvailable: true,
    attendanceBlock: AttendanceBlock.deviceNotEnrolled,
  );

  const attendance = Text('ATTENDANCE SCREEN');

  setUpAll(
    () =>
        registerFallbackValue(const DeviceGateDecision(DeviceGateStatus.ready)),
  );

  setUp(() {
    Get.testMode = true;
    gate = _MockGate();
    when(() => gate.device).thenReturn(null);
    when(() => gate.confirmKeystore(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.first as DeviceGateDecision,
    );
  });

  tearDown(Get.reset);

  void decides(DeviceGateStatus status, {DeviceStatus? device}) => when(
    () => gate.evaluate(),
  ).thenReturn(DeviceGateDecision(status, device: device));

  var sessionNotices = 0;

  Future<void> pumpGate(
    WidgetTester tester, {
    DeviceProofGate? withGate,
    Future<Object?> Function()? openEnrollment,
  }) async {
    sessionNotices = 0;
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        home: AttendanceDeviceGate(
          gate: withGate,
          openEnrollment: openEnrollment,
          onSessionEnded: () async => sessionNotices++,
          child: attendance,
        ),
      ),
    );
  }

  group('the middleware', () {
    test('wraps the capture screen, and only it', () {
      final middleware = AttendanceDeviceGateMiddleware();

      expect(
        middleware.onPageBuilt(const AttendanceView()),
        isA<AttendanceDeviceGate>(),
      );
      expect(
        middleware.onPageBuilt(const AttendanceListView()),
        isA<AttendanceListView>(),
      );
    });
  });

  group('when nothing is required', () {
    testWidgets('the attendance screen is there on the first frame, and '
        'nothing is asked', (tester) async {
      decides(DeviceGateStatus.ready);

      await pumpGate(tester, withGate: gate);

      expect(find.text('ATTENDANCE SCREEN'), findsOneWidget);
      verifyNever(() => gate.ensureReady());
      verifyNever(() => gate.refresh());
    });

    testWidgets('without the app-wide services there is no gate at all', (
      tester,
    ) async {
      await pumpGate(tester);

      expect(find.text('ATTENDANCE SCREEN'), findsOneWidget);
    });
  });

  group('at the entry', () {
    testWidgets('not enrolled: the status card, then the code, then '
        'attendance', (tester) async {
      decides(DeviceGateStatus.notEnrolled, device: enrollmentOpen);
      when(() => gate.ensureReady()).thenAnswer(
        (_) async => const DeviceGateDecision(DeviceGateStatus.ready),
      );
      var opened = 0;

      await pumpGate(
        tester,
        withGate: gate,
        openEnrollment: () async {
          opened++;
          return true;
        },
      );

      expect(find.text('Perangkat Absensi Belum Terdaftar'), findsOneWidget);
      expect(find.text('ATTENDANCE SCREEN'), findsNothing);

      await tester.ensureVisible(find.text('Masukkan Kode Aktivasi').last);
      await tester.tap(find.text('Masukkan Kode Aktivasi').last);
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(find.text('ATTENDANCE SCREEN'), findsOneWidget);
    });

    testWidgets('a proof that is due runs before the screen opens', (
      tester,
    ) async {
      decides(DeviceGateStatus.needsProof);
      final pending = Completer<DeviceGateDecision>();
      when(() => gate.ensureReady()).thenAnswer((_) => pending.future);

      await pumpGate(tester, withGate: gate);

      expect(find.text('Memeriksa Perangkat'), findsOneWidget);
      expect(find.text('ATTENDANCE SCREEN'), findsNothing);

      pending.complete(const DeviceGateDecision(DeviceGateStatus.ready));
      await tester.pumpAndSettle();

      expect(find.text('ATTENDANCE SCREEN'), findsOneWidget);
    });

    testWidgets('a lost key is a recovery', (tester) async {
      decides(DeviceGateStatus.needsProof, device: enrollmentOpen);
      when(() => gate.ensureReady()).thenAnswer(
        (_) async => const DeviceGateDecision(
          DeviceGateStatus.recovery,
          device: enrollmentOpen,
        ),
      );

      await pumpGate(tester, withGate: gate);
      await tester.pumpAndSettle();

      expect(find.text('Hubungi HR untuk Mengganti Perangkat'), findsOneWidget);
      expect(find.text('ATTENDANCE SCREEN'), findsNothing);
    });

    testWidgets('an open but optional enrolment can be passed over', (
      tester,
    ) async {
      decides(
        DeviceGateStatus.offerEnrollment,
        device: const DeviceStatus(enrollmentAvailable: true),
      );

      await pumpGate(tester, withGate: gate);
      await tester.ensureVisible(find.text('Lanjut ke Absensi'));
      await tester.tap(find.text('Lanjut ke Absensi'));
      await tester.pumpAndSettle();

      verify(() => gate.deferEnrollment()).called(1);
      expect(find.text('ATTENDANCE SCREEN'), findsOneWidget);
    });
  });

  group('bad connection and double taps', () {
    testWidgets('a proof whose answer replaced the token asks to sign in '
        'again', (tester) async {
      decides(DeviceGateStatus.needsProof);
      when(() => gate.ensureReady()).thenAnswer(
        (_) async => const DeviceGateDecision(DeviceGateStatus.sessionEnded),
      );

      await pumpGate(tester, withGate: gate);
      await tester.pumpAndSettle();

      expect(sessionNotices, 1);
      expect(find.text('Silakan Masuk Kembali'), findsOneWidget);
      expect(find.text('ATTENDANCE SCREEN'), findsNothing);
    });

    testWidgets('"Coba Lagi" tapped twice runs one check', (tester) async {
      decides(DeviceGateStatus.needsProof);
      when(() => gate.ensureReady()).thenAnswer(
        (_) async => const DeviceGateDecision(DeviceGateStatus.offline),
      );
      final pending = Completer<DeviceGateDecision>();
      when(() => gate.refresh()).thenAnswer((_) => pending.future);

      await pumpGate(tester, withGate: gate);
      await tester.pumpAndSettle();
      expect(find.text('Tidak Ada Koneksi'), findsOneWidget);

      final retry = find.text('Coba Lagi');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.tap(retry, warnIfMissed: false);
      await tester.pump();

      verify(() => gate.refresh()).called(1);

      pending.complete(const DeviceGateDecision(DeviceGateStatus.ready));
      await tester.pumpAndSettle();
      expect(find.text('ATTENDANCE SCREEN'), findsOneWidget);
    });

    testWidgets('"Masukkan Kode Aktivasi" tapped twice opens one screen', (
      tester,
    ) async {
      decides(DeviceGateStatus.notEnrolled, device: enrollmentOpen);
      when(() => gate.ensureReady()).thenAnswer(
        (_) async => const DeviceGateDecision(DeviceGateStatus.ready),
      );
      final closed = Completer<Object?>();
      var opened = 0;

      await pumpGate(
        tester,
        withGate: gate,
        openEnrollment: () {
          opened++;
          return closed.future;
        },
      );

      final button = find.text('Masukkan Kode Aktivasi').last;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();

      expect(opened, 1);

      closed.complete(true);
      await tester.pumpAndSettle();
    });
  });

  group('403 DEVICE_PROOF_REQUIRED from an attendance call', () {
    late AttendanceController controller;

    setUp(() {
      final repository = _MockRepository();
      final location = _MockLocation();
      final session = _MockSession();
      final storage = _MockStorage();
      final permission = _MockPermission();

      when(() => repository.context()).thenAnswer(
        (_) async => const AttendanceContext(
          attendanceEnabled: true,
          nextPresence: PresenceDirection.clockIn,
        ),
      );
      when(() => repository.workspace).thenReturn('acme');
      when(
        () => permission.status(),
      ).thenAnswer((_) async => CameraPermission.granted);
      when(
        () => permission.request(),
      ).thenAnswer((_) async => CameraPermission.granted);
      when(() => storage.read<bool>(any())).thenReturn(null);
      when(() => session.user).thenReturn(null);
      when(() => location.currentPosition()).thenAnswer(
        (_) async => const LocationRejected(LocationFailure.unavailable),
      );
      when(() => location.currentPosition(mayAsk: false)).thenAnswer(
        (_) async => const LocationRejected(LocationFailure.unavailable),
      );

      controller = Get.put<AttendanceController>(
        AttendanceController(
          repository: repository,
          location: location,
          session: session,
          storage: storage,
          camera: permission,
          scannerFactory: _FakeScanner.new,
        ),
      );

      decides(DeviceGateStatus.ready);
    });

    /// What the screen's own classifier makes of the refusal — the input the
    /// gate reads. The code must survive it.
    AttendanceRefusal proofRequired() => AttendanceRepository.refusalFor(
      const ApiException(
        'Bukti perangkat diperlukan.',
        status: 403,
        code: 'DEVICE_PROOF_REQUIRED',
      ),
    );

    testWidgets('the classifier keeps the code the gate reads', (tester) async {
      expect(proofRequired().code, DeviceErrorCodes.proofRequired);
    });

    testWidgets('is proven again once, and the person is asked to retry', (
      tester,
    ) async {
      when(() => gate.reproveAfterRefusal()).thenAnswer(
        (_) async => const DeviceGateDecision(DeviceGateStatus.ready),
      );

      await pumpGate(tester, withGate: gate);
      await tester.pump();

      controller.stage.value = CaptureStage.refused;
      controller.refusal.value = proofRequired();
      await tester.pump();
      await tester.pump();

      verify(() => gate.reproveAfterRefusal()).called(1);
      expect(
        controller.refusal.value?.message,
        'Perangkat sudah diverifikasi ulang. Silakan coba lagi.',
      );
      expect(controller.refusal.value?.kind, isNot(RefusalKind.unanswered));
    });

    testWidgets('a key that no longer matches becomes the recovery card', (
      tester,
    ) async {
      when(() => gate.reproveAfterRefusal()).thenAnswer(
        (_) async => const DeviceGateDecision(
          DeviceGateStatus.recovery,
          device: enrollmentOpen,
        ),
      );

      await pumpGate(tester, withGate: gate);
      await tester.pump();

      controller.stage.value = CaptureStage.refused;
      controller.refusal.value = proofRequired();
      await tester.pumpAndSettle();

      expect(find.text('Hubungi HR untuk Mengganti Perangkat'), findsOneWidget);
      expect(find.text('ATTENDANCE SCREEN'), findsNothing);
    });

    testWidgets('a re-proof whose answer replaced the token asks to sign in '
        'again', (tester) async {
      when(() => gate.reproveAfterRefusal()).thenAnswer(
        (_) async => const DeviceGateDecision(DeviceGateStatus.sessionEnded),
      );

      await pumpGate(tester, withGate: gate);
      await tester.pump();

      controller.stage.value = CaptureStage.refused;
      controller.refusal.value = proofRequired();
      await tester.pumpAndSettle();

      expect(sessionNotices, 1);
    });

    testWidgets('other refusals are left alone', (tester) async {
      await pumpGate(tester, withGate: gate);
      await tester.pump();

      controller.refusal.value = const AttendanceRefusal(
        kind: RefusalKind.clockRejected,
        message: 'Anda di luar area.',
        code: 'outside_geofence',
      );
      await tester.pump();

      verifyNever(() => gate.reproveAfterRefusal());
      expect(controller.refusal.value?.message, 'Anda di luar area.');
    });

    testWidgets('a recorded clock earns the next refusal its own re-proof', (
      tester,
    ) async {
      await pumpGate(tester, withGate: gate);
      await tester.pump();
      clearInteractions(gate);

      controller.receipt.value = const AttendanceReceipt(
        direction: PresenceDirection.clockIn,
        message: 'Absensi tercatat.',
      );
      await tester.pump();

      verify(() => gate.resetRetryBudget()).called(1);
    });
  });
}
