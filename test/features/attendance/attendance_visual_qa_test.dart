@Tags(<String>['visual'])
library;

import 'package:esas/core/services/camera_permission_service.dart';
import 'package:esas/core/services/location_service.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/controllers/bottom_nav_controller.dart';
import 'package:esas/features/attendance/data/models/attendance_context.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:esas/features/attendance/presentation/views/attendance_view.dart';
import 'package:esas/features/attendance/presentation/widgets/attendance_camera_viewport.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AttendanceRepository {}

class _MockLocation extends Mock implements LocationService {}

class _MockSession extends Mock implements SessionRepository {}

class _MockStorage extends Mock implements LocalStorage {}

class _MockPermission extends Mock implements CameraPermissionService {}

class _FakeScanner extends ValueNotifier<MobileScannerState>
    implements MobileScannerController {
  _FakeScanner()
    : super(
        const MobileScannerState.uninitialized().copyWith(
          isInitialized: true,
          isRunning: true,
          torchState: TorchState.off,
        ),
      );

  @override
  bool get autoStart => false;

  @override
  Stream<BarcodeCapture> get barcodes => const Stream<BarcodeCapture>.empty();

  @override
  Future<void> start({CameraFacing? cameraDirection}) async {
    // Notifies, so the controller's listener sees the transition and moves to
    // `ScannerState.ready` — the state these fixtures exist to show.
    value = value.copyWith(isInitialized: true, isRunning: true);
    notifyListeners();
  }

  @override
  Future<void> stop() async {}

  @override
  void attach() {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> dispose() async => super.dispose();

  /// A stand-in for the camera image.
  ///
  /// Deliberately a flat, mid-dark field rather than a photograph: what these
  /// fixtures are for is the legibility of the overlay — corner markers,
  /// instruction block, torch — and a busy stock image would make a frame that
  /// is too faint look fine.
  @override
  Widget buildCameraView() => const ColoredBox(color: Color(0xFF2A2E33));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Absensi drawn to PNG, in the states a simulator cannot show.
///
/// A simulator has no camera, so the only thing that can be inspected on one is
/// the failure path — which is exactly the half of this screen a reviewer least
/// needs to see. These fixtures cover the other half: the scan frame over a
/// stand-in preview, the face guide, the confirmation, and the two camera
/// refusals whose *primary buttons* used to be the wrong way round.
///
/// Diagnostic artefacts, not a CI gate. The file is tagged `visual` so
/// `flutter test` skips it — rasterisation differs between Flutter versions,
/// machines and installed fonts, and a byte comparison would fail for reasons
/// that have nothing to do with this screen.
///
/// ```
/// flutter test test/features/attendance/attendance_visual_qa_test.dart --update-goldens
/// ```
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _MockRepository repository;
  late _MockLocation location;
  late _MockSession session;
  late _MockStorage storage;
  late _MockPermission permission;

  setUp(() {
    repository = _MockRepository();
    location = _MockLocation();
    session = _MockSession();
    storage = _MockStorage();
    permission = _MockPermission();

    when(() => storage.read<bool>(any())).thenReturn(true);
    when(() => session.user).thenReturn(null);
    // Every screen now takes a fix for the record, geofence or not.
    when(() => location.currentPosition()).thenAnswer(
      (_) async => const LocationRejected(LocationFailure.unavailable),
    );
    when(
      () => permission.status(),
    ).thenAnswer((_) async => CameraPermission.granted);
  });

  tearDown(Get.reset);

  Future<AttendanceController> render(
    WidgetTester tester,
    String name, {
    Size size = const Size(390, 844),
    ThemeData? theme,
    void Function(AttendanceController)? after,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Get.put<BottomNavController>(
      BottomNavController(destinations: const ['/home', '/attendance']),
    );

    final controller = AttendanceController(
      repository: repository,
      location: location,
      session: session,
      storage: storage,
      camera: permission,
      scannerFactory: _FakeScanner.new,
    );

    Get.put<AttendanceController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('id', 'ID'),
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('id', 'ID')],
        theme: theme ?? AppTheme.lightTheme,
        home: const AttendanceView(),
      ),
    );

    // `pump`, not `pumpAndSettle`: several of these states carry indeterminate
    // progress, and a settle waits on an animation that never ends. A handful
    // of frames is enough for the async context load to land and for the
    // selector's 120ms transition to finish.
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    after?.call(controller);

    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    await expectLater(
      find.byType(AttendanceView),
      matchesGoldenFile('goldens/$name.png'),
    );

    return controller;
  }

  AttendanceContext ready({bool faceEnrolled = true}) => AttendanceContext(
    attendanceEnabled: true,
    faceEnrolled: faceEnrolled,
    nextPresence: PresenceDirection.clockIn,
    shift: const AttendanceShift(
      name: 'Shift Pagi',
      start: '08:00:00',
      end: '17:00:00',
    ),
  );

  testWidgets('a — QR mode, camera live', (tester) async {
    when(() => repository.context()).thenAnswer((_) async => ready());

    await render(tester, 'attendance_a_qr');
  });

  testWidgets('b — face mode, before the camera opens', (tester) async {
    when(() => repository.context()).thenAnswer((_) async => ready());

    await render(
      tester,
      'attendance_b_face',
      after: (controller) => controller.mode.value = AttendanceMethod.face,
    );
  });

  testWidgets('c — camera unavailable on this device', (tester) async {
    when(() => repository.context()).thenAnswer((_) async => ready());

    await render(
      tester,
      'attendance_c_no_camera',
      after: (controller) =>
          controller.scannerState.value = ScannerState.unsupported,
    );
  });

  testWidgets('d — camera permission denied permanently', (tester) async {
    when(() => repository.context()).thenAnswer((_) async => ready());
    when(
      () => permission.status(),
    ).thenAnswer((_) async => CameraPermission.permanentlyDenied);

    await render(tester, 'attendance_d_permission');
  });

  testWidgets('e — the clock the server confirmed', (tester) async {
    when(() => repository.context()).thenAnswer((_) async => ready());

    await render(
      tester,
      'attendance_e_receipt',
      after: (controller) => controller.receipt.value = const AttendanceReceipt(
        direction: PresenceDirection.clockIn,
        message: 'Absen masuk berhasil.',
        recordedAt: '08:03:11',
      ),
    );
  });

  testWidgets('f — face not enrolled, on a small screen', (tester) async {
    when(
      () => repository.context(),
    ).thenAnswer((_) async => ready(faceEnrolled: false));

    await render(
      tester,
      'attendance_f_not_enrolled',
      size: const Size(320, 568),
    );
  });

  testWidgets('g — QR mode in dark theme', (tester) async {
    when(() => repository.context()).thenAnswer((_) async => ready());

    await render(tester, 'attendance_g_dark', theme: AppTheme.darkTheme);
  });

  testWidgets('h — the scan frame alone, at three widths', (tester) async {
    // The overlay on its own, so the corner markers and the instruction block
    // can be read at the sizes they are actually drawn at.
    for (final width in const <double>[320, 390, 430]) {
      tester.view.physicalSize = Size(width, 420);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: AttendanceCameraViewport(child: QrScanOverlay(hint: null)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AttendanceCameraViewport),
        matchesGoldenFile('goldens/attendance_h_frame_${width.toInt()}.png'),
      );
    }
  });

  testWidgets('i — the face guide, mid-sequence', (tester) async {
    tester.view.physicalSize = const Size(390, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: AttendanceCameraViewport(
              child: LivenessOverlay(
                headline: 'Ikuti gerakan yang diminta',
                // The server's own sentence. The app never writes one.
                instruction:
                    'Tolehkan kepala ke kiri Anda, tahan sebentar, lalu '
                    'kembali menghadap kamera.',
                progress: 0.62,
                step: 1,
                totalSteps: 3,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AttendanceCameraViewport),
      matchesGoldenFile('goldens/attendance_i_face_guide.png'),
    );
  });
}
