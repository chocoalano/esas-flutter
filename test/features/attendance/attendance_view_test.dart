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
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AttendanceRepository {}

class _MockLocation extends Mock implements LocationService {}

class _MockSession extends Mock implements SessionRepository {}

class _MockStorage extends Mock implements LocalStorage {}

class _MockPermission extends Mock implements CameraPermissionService {}

class _FakeScanner extends ValueNotifier<MobileScannerState>
    implements MobileScannerController {
  _FakeScanner() : super(const MobileScannerState.uninitialized());

  @override
  Future<void> start({CameraFacing? cameraDirection}) async {}

  @override
  Future<void> stop() async {}

  @override
  void attach() {}

  @override
  Future<void> dispose() async => super.dispose();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The attendance workspace as it is drawn.
///
/// Every case here is one the old screen either could not reach or reached with
/// the wrong words: a permanent camera denial that led with "Coba lagi", a
/// simulator with no camera at all that was told to check its permissions, and
/// a second attendance method that had no way onto the screen.
///
/// The camera preview itself is never mounted in these tests, and that is a
/// property of the view rather than a trick of the harness: a texture is only
/// created for a state that has a camera behind it.
/// A filled button carrying this label.
///
/// `FilledButton.icon` builds a private subclass, and `find.byType` matches an
/// exact runtime type — so the obvious `widgetWithText(FilledButton, …)` finds
/// nothing for any button with an icon on it.
Finder filledWithText(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

/// Every filled button on screen, icon or not.
Finder get filledButtons =>
    find.byWidgetPredicate((widget) => widget is FilledButton);

void main() {
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

    when(() => storage.read<bool>(any())).thenReturn(null);
    when(() => session.user).thenReturn(null);
    when(() => location.currentPosition()).thenAnswer(
      (_) async => const LocationRejected(LocationFailure.unavailable),
    );
    when(
      () => permission.status(),
    ).thenAnswer((_) async => CameraPermission.permanentlyDenied);
    when(() => repository.context()).thenAnswer(
      (_) async => const AttendanceContext(
        attendanceEnabled: true,
        nextPresence: PresenceDirection.clockIn,
      ),
    );
  });

  tearDown(Get.reset);

  Future<AttendanceController> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
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
      GetMaterialApp(theme: AppTheme.lightTheme, home: const AttendanceView()),
    );
    await tester.pumpAndSettle();

    return controller;
  }

  group('the page is not a black rectangle', () {
    testWidgets('the scaffold keeps the app surface, whatever the camera does', (
      tester,
    ) async {
      await pump(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      // The old screen painted `colorScheme.scrim` here, so a camera that could
      // not open turned the entire page black — header, controls and all.
      expect(scaffold.backgroundColor, AppTheme.lightTheme.colorScheme.surface);
    });

    testWidgets('header, selector and bottom navigation survive a failure', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Absensi'), findsWidgets);
      expect(find.text('Scan QR'), findsOneWidget);
      expect(find.text('Verifikasi wajah'), findsOneWidget);
      expect(find.byType(AttendanceCameraViewport), findsOneWidget);
      // Nothing about a camera failure may cost somebody their orientation.
      expect(find.byTooltip('Riwayat absensi'), findsOneWidget);
    });
  });

  group('camera permission states say the right thing, in the right order', () {
    testWidgets('a permanent denial leads with Settings', (tester) async {
      await pump(tester);

      expect(find.text('Izin kamera ditolak permanen'), findsOneWidget);

      // The primary action is the one that can actually fix it. "Coba lagi" as
      // the primary here is a button that can only repeat itself — the OS will
      // not show the prompt again.
      expect(filledWithText('Buka pengaturan'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Saya sudah mengizinkan'),
        findsOneWidget,
      );
    });

    testWidgets('a permission never asked for leads with the request', (
      tester,
    ) async {
      when(
        () => permission.status(),
      ).thenAnswer((_) async => CameraPermission.askable);

      await pump(tester);

      expect(find.text('Izin kamera diperlukan'), findsOneWidget);
      expect(filledWithText('Izinkan kamera'), findsOneWidget);
      // Sending somebody who has never been asked to Settings asks them to fix
      // something that is not broken.
      expect(find.text('Buka pengaturan'), findsNothing);
    });

    testWidgets('a device with no camera does not blame a permission', (
      tester,
    ) async {
      final controller = await pump(tester);

      controller.reportScannerFailure(
        const MobileScannerException(
          errorCode: MobileScannerErrorCode.unsupported,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kamera tidak tersedia'), findsOneWidget);
      expect(find.textContaining('izin'), findsNothing);
    });

    testWidgets('a restricted camera offers neither button', (tester) async {
      when(
        () => permission.status(),
      ).thenAnswer((_) async => CameraPermission.restricted);

      await pump(tester);

      expect(find.text('Kamera dibatasi perangkat'), findsOneWidget);
      expect(filledButtons, findsNothing);
    });
  });

  group('the method selector', () {
    testWidgets('marks the unavailable method, and says why', (tester) async {
      await pump(tester);

      expect(find.textContaining('belum didaftarkan HR'), findsOneWidget);

      final segment = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Verifikasi wajah'),
              matching: find.byType(Semantics),
            )
            .first,
      );

      // Not colour alone: the state is spoken, and the segment is not enabled.
      expect(segment.label, contains('belum tersedia'));
    });

    testWidgets('an enrolled employee can reach the face method', (
      tester,
    ) async {
      when(() => repository.context()).thenAnswer(
        (_) async => const AttendanceContext(
          attendanceEnabled: true,
          faceEnrolled: true,
          nextPresence: PresenceDirection.clockIn,
        ),
      );

      final controller = await pump(tester);

      await tester.tap(find.text('Verifikasi wajah'));
      await tester.pumpAndSettle();

      expect(controller.mode.value, AttendanceMethod.face);
      // The face panel explains itself before any camera opens, and offers the
      // start rather than opening one on arrival.
      expect(find.text('Absen masuk dengan wajah'), findsOneWidget);
      expect(filledWithText('Mulai verifikasi'), findsOneWidget);
    });

    testWidgets('the selector stays visible in every failure state', (
      tester,
    ) async {
      when(() => repository.context()).thenAnswer(
        (_) async => const AttendanceContext(attendanceEnabled: false),
      );

      await pump(tester);

      expect(find.text('Absensi belum diaktifkan'), findsOneWidget);
      expect(find.text('Scan QR'), findsOneWidget);
      expect(find.text('Verifikasi wajah'), findsOneWidget);
    });
  });

  group('the intent line', () {
    testWidgets('names the clock that is owed, with the shift', (tester) async {
      when(() => repository.context()).thenAnswer(
        (_) async => const AttendanceContext(
          attendanceEnabled: true,
          nextPresence: PresenceDirection.clockOut,
          shift: AttendanceShift(
            name: 'Shift Malam',
            start: '22:00',
            end: '06:00',
            crossesMidnight: true,
          ),
        ),
      );

      await pump(tester);

      // `(+1 hari)` because the shift ends on the following date. Without it
      // "06:00" reads as a time earlier today, which is the past — and that is
      // the whole reason the server sends `spans_midnight` at all.
      expect(
        find.text('Absen pulang · Shift Malam 22:00–06:00 (+1 hari)'),
        findsOneWidget,
      );
    });

    testWidgets('is simply absent when the server said nothing', (
      tester,
    ) async {
      when(() => repository.context()).thenAnswer(
        (_) async => const AttendanceContext(attendanceEnabled: true),
      );

      await pump(tester);

      expect(find.text('Absensi'), findsWidgets);
      expect(find.textContaining('Absen masuk'), findsNothing);
    });
  });

  group('outcomes', () {
    testWidgets('a confirmed clock shows the SERVER\'s time', (tester) async {
      final controller = await pump(tester);

      controller.receipt.value = const AttendanceReceipt(
        direction: PresenceDirection.clockIn,
        message: 'Absen masuk berhasil.',
        recordedAt: '08:03:11',
      );
      await tester.pumpAndSettle();

      expect(find.text('Absen masuk berhasil'), findsOneWidget);
      expect(find.text('08:03:11'), findsOneWidget);
      expect(find.text('Tersimpan di server.'), findsOneWidget);
    });

    testWidgets('an unanswered request offers no retry', (tester) async {
      final controller = await pump(tester);

      controller.refusal.value = const AttendanceRefusal(
        kind: RefusalKind.unanswered,
        message: 'Jawaban dari server belum diterima.',
        code: 'timeout',
      );
      controller.stage.value = CaptureStage.refused;
      await tester.pumpAndSettle();

      expect(find.text('Status absensi belum pasti'), findsOneWidget);
      // Retrying here walks somebody into a duplicate the server will refuse.
      expect(find.text('Pindai lagi'), findsNothing);
      expect(filledWithText('Lihat riwayat'), findsOneWidget);
    });

    testWidgets('a refused code is not called a QR read failure', (
      tester,
    ) async {
      final controller = await pump(tester);

      controller.refusal.value = const AttendanceRefusal(
        kind: RefusalKind.clockRejected,
        message: 'Anda berada 840 m dari lokasi kantor.',
        code: 'outside_geofence',
      );
      controller.stage.value = CaptureStage.refused;
      await tester.pumpAndSettle();

      // The QR was read perfectly. What was refused is the clock.
      expect(find.text('Absensi belum dapat diproses'), findsOneWidget);
      expect(find.textContaining('840 m'), findsOneWidget);
    });

    testWidgets('a submission in flight never claims success', (tester) async {
      final controller = await pump(tester);

      controller.stage.value = CaptureStage.submitting;
      // `pump`, not `pumpAndSettle`: this state carries an indeterminate
      // progress bar, and a settle waits for an animation that never ends.
      await tester.pump();

      expect(find.text('Memverifikasi absensi'), findsOneWidget);
      expect(find.textContaining('berhasil'), findsNothing);
    });
  });

  group('location', () {
    testWidgets('a geofence refusal keeps its own cause and action', (
      tester,
    ) async {
      when(() => repository.context()).thenAnswer(
        (_) async => const AttendanceContext(
          attendanceEnabled: true,
          nextPresence: PresenceDirection.clockIn,
          geofence: AttendanceGeofence(
            required_: true,
            latitude: -6.2,
            longitude: 106.8,
            radiusMetres: 30,
          ),
        ),
      );
      when(() => location.currentPosition()).thenAnswer(
        (_) async => const LocationRejected(LocationFailure.serviceDisabled),
      );

      await pump(tester);

      expect(find.text('GPS tidak aktif'), findsOneWidget);
      // Not "buka pengaturan aplikasi", which cannot switch a GPS radio on.
      expect(filledWithText('Buka pengaturan lokasi'), findsOneWidget);
    });

    testWidgets(
      'no geofence means no location chip, even though a fix is taken',
      (tester) async {
        await pump(tester);

        // The coordinates go on the record either way, but a chip about a check
        // the company does not perform would be reporting on a rule that does not
        // apply — and a red one would alarm somebody over something that cannot
        // block them.
        expect(find.textContaining('Lokasi'), findsNothing);
      },
    );
  });

  group('responsive', () {
    for (final width in const <double>[320, 360, 375, 390, 393, 412, 430]) {
      testWidgets('lays out at ${width.toInt()}dp without overflow', (
        tester,
      ) async {
        await pump(tester, size: Size(width, 720));

        expect(tester.takeException(), isNull);
        expect(find.byType(AttendanceCameraViewport), findsOneWidget);
        expect(find.text('Scan QR'), findsOneWidget);
      });
    }

    testWidgets('a short screen still shows selector, viewport and status', (
      tester,
    ) async {
      await pump(tester, size: const Size(320, 568));

      expect(tester.takeException(), isNull);
      expect(find.text('Absensi'), findsWidgets);
      expect(find.byType(AttendanceCameraViewport), findsOneWidget);
    });
  });
}
