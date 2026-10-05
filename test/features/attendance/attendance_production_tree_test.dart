import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/controllers/bottom_nav_controller.dart';
import 'package:esas/features/attendance/data/models/attendance_context.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_pages.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:esas/features/attendance/presentation/views/attendance_view.dart';
import 'package:esas/features/attendance/presentation/widgets/attendance_camera_viewport.dart';
import 'package:esas/features/attendance/presentation/widgets/attendance_method_selector.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/features/notification/presentation/routes/notification_routes.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:esas/features/profile/presentation/routes/profile_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AttendanceRepository {}

class _MockSession extends Mock implements SessionRepository {}

class _MockStorage extends Mock implements LocalStorage {}

/// Absensi as the APPLICATION builds it, not as a test builds it.
///
/// The sibling file for Beranda exists because an implementation report once
/// claimed a change that the simulator did not show — the binary was older than
/// the source — and the incident exposed a real hole: every widget test built
/// the view directly, so not one of them proved that the route table, the
/// binding and the controller produce the same screen.
///
/// The hole is wider here. This screen's controller is the thing that opens a
/// camera, and it is reached only through `AttendanceBinding`; a test that
/// constructs the controller by hand proves nothing about whether the real
/// binding can even build it. What is traversed below is
/// `AttendanceRoutes.attendance` → `AttendancePages.pages` → `AttendanceBinding`
/// → `AttendanceController` → `AttendanceView`, with the repository put in
/// front of the binding so no request leaves the process.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepository repository;

  /// The camera permission, answered without a platform.
  ///
  /// The production binding builds the real `CameraPermissionService`, so this
  /// is the one seam the test has to stand in for. The number is the index of a
  /// `PermissionStatus` case: `0` is `denied`, which is the honest answer for a
  /// machine with no camera and no user to ask.
  void stubPermissions({int status = 0}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async => switch (call.method) {
            'checkPermissionStatus' => status,
            'requestPermissions' => <int, int>{6: status},
            'shouldShowRequestPermissionRationale' => false,
            'openAppSettings' => true,
            _ => null,
          },
        );
  }

  setUp(() {
    repository = _MockRepository();
    stubPermissions();

    when(() => repository.context()).thenAnswer(
      (_) async => const AttendanceContext(
        attendanceEnabled: true,
        faceEnrolled: true,
        nextPresence: PresenceDirection.clockIn,
        shift: AttendanceShift(
          name: 'Shift Pagi',
          start: '08:00:00',
          end: '17:00:00',
        ),
      ),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          null,
        );
    Get.reset();
  });

  Future<void> pumpProductionAttendance(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Put in place BEFORE the route opens, so `AttendanceBinding` finds it
    // instead of building a real repository over `ApiClient`.
    Get.put<AttendanceRepository>(repository);
    Get.put<SessionRepository>(_MockSession());
    Get.put<LocalStorage>(_MockStorage());
    Get.put<BottomNavController>(
      BottomNavController(
        destinations: const <String>[
          HomeRoutes.home,
          AttendanceRoutes.attendance,
          PermitRoutes.permit,
          NotificationRoutes.notification,
          ProfileRoutes.profile,
        ],
      ),
    );

    final storage = Get.find<LocalStorage>() as _MockStorage;
    when(() => storage.read<bool>(any())).thenReturn(null);

    final session = Get.find<SessionRepository>() as _MockSession;
    when(() => session.user).thenReturn(null);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: AttendanceRoutes.attendance,
        // The PRODUCTION route table, not a stand-in page.
        getPages: AttendancePages.pages,
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('the real route builds the real workspace', (tester) async {
    await pumpProductionAttendance(tester);

    expect(find.byType(AttendanceView), findsOneWidget);
    expect(Get.isRegistered<AttendanceController>(), isTrue);

    // Both methods, from the real binding through the real controller.
    expect(find.byType(AttendanceMethodSelector), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Verifikasi wajah'), findsOneWidget);

    // The camera is one panel on the page, not the page.
    expect(find.byType(AttendanceCameraViewport), findsOneWidget);
  });

  testWidgets('the context the binding fetched reaches the header', (
    tester,
  ) async {
    await pumpProductionAttendance(tester);

    expect(find.text('Absen masuk · Shift Pagi 08:00–17:00'), findsOneWidget);
    verify(() => repository.context()).called(1);
  });

  testWidgets('an enrolled employee can switch method on the real screen', (
    tester,
  ) async {
    await pumpProductionAttendance(tester);

    await tester.tap(find.text('Verifikasi wajah'));
    await tester.pumpAndSettle();

    expect(Get.find<AttendanceController>().mode.value, AttendanceMethod.face);
    expect(find.text('Absen masuk dengan wajah'), findsOneWidget);
  });

  testWidgets('leaving the route disposes the controller, and the camera', (
    tester,
  ) async {
    await pumpProductionAttendance(tester);

    expect(Get.isRegistered<AttendanceController>(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // GetX tears the route-scoped controller down, and `onClose` is what hands
    // the sensor back. A camera left running behind a screen nobody is looking
    // at is a privacy problem before it is a battery one.
    expect(Get.isRegistered<AttendanceController>(), isFalse);
  });

  testWidgets('a permanently denied camera still draws the whole page', (
    tester,
  ) async {
    // 4 is `permanentlyDenied` in permission_handler's wire encoding — the
    // index of the case in `PermissionStatus`, which is what the platform
    // channel sends across.
    stubPermissions(status: 4);

    await pumpProductionAttendance(tester);

    expect(find.text('Izin kamera ditolak permanen'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.byTooltip('Riwayat absensi'), findsOneWidget);
  });
}
