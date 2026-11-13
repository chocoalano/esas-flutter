import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/home/data/models/attendance_device_step.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/data/services/home_api_service.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/widgets/today_work_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements HomeApiService {}

class _MockSession extends Mock implements SessionRepository {}

/// UX-C31. Beranda's attendance card told an enrolled phone — one that only
/// needs the automatic check at the Absensi door — "Perangkat belum terdaftar"
/// or "Izin absensi terbatas". It now says the attendance-device step the
/// session names, and nothing changes while the backend flag is off.
void main() {
  AuthUser userWith(Map<String, dynamic> device) => AuthUser.fromJson({
    'id': 7,
    'attendance_enabled': true,
    'device': {'can_record_attendance': false, ...device},
  });

  group('which step the session names', () {
    test('enrolled, sign-in not yet verified → verify at Absensi', () {
      final step = attendanceDeviceStepOf(
        userWith({
          'is_registered_device': true,
          'proof_required': true,
          'key_enrolled': true,
          'attendance_block': 'DEVICE_PROOF_REQUIRED',
        }),
      );

      expect(step?.step, AttendanceDeviceStep.verifyAtAttendance);
      expect(step, isA<AttendanceAccessException>());
    });

    test('no key → HR code', () {
      final step = attendanceDeviceStepOf(
        userWith({
          'proof_required': true,
          'key_enrolled': false,
          'attendance_block': 'DEVICE_NOT_ENROLLED',
        }),
      );

      expect(step?.step, AttendanceDeviceStep.notEnrolled);
    });

    test('proof required without a key is not a "verify" step', () {
      expect(
        attendanceDeviceStepOf(
          userWith({
            'key_enrolled': false,
            'attendance_block': 'DEVICE_PROOF_REQUIRED',
          }),
        ),
        isNull,
      );
    });

    test('flag off: no step, the old sentences stay', () {
      expect(
        attendanceDeviceStepOf(
          userWith({
            'is_registered_device': false,
            'attendance_block': 'DEVICE_NOT_REGISTERED',
          }),
        ),
        isNull,
      );
      expect(attendanceDeviceStepOf(userWith({})), isNull);
      expect(attendanceDeviceStepOf(null), isNull);
    });

    test('the repository raises the step before any request', () async {
      final api = _MockApi();
      final session = _MockSession();
      when(() => session.user).thenReturn(
        userWith({
          'key_enrolled': true,
          'attendance_block': 'DEVICE_PROOF_REQUIRED',
        }),
      );

      await expectLater(
        HomeRepository(api: api, session: session).todayAttendance(),
        throwsA(
          isA<AttendanceDeviceStepException>().having(
            (e) => e.step,
            'step',
            AttendanceDeviceStep.verifyAtAttendance,
          ),
        ),
      );
      await expectLater(
        HomeRepository(api: api, session: session).scheduleCalendar(),
        throwsA(isA<AttendanceDeviceStepException>()),
      );
      verifyNever(() => api.attendanceContext());
    });
  });

  group('the card', () {
    Future<int> pumpCard(
      WidgetTester tester, {
      required ApiException error,
      HomeTodayState state = HomeTodayState.unavailable,
      Size? size,
      double scale = 1.0,
    }) async {
      if (size != null) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
      }
      var opened = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TodayWorkCard(
                    state: state,
                    shiftName: null,
                    scheduleIn: null,
                    scheduleOut: null,
                    timeIn: state == HomeTodayState.working ? '08:03' : null,
                    timeOut: null,
                    lateMinutes: null,
                    nextPunch: AttendancePunch.clockOut,
                    canClock: false,
                    dayContext: null,
                    error: error,
                    date: null,
                    onClock: () => opened++,
                    onSignIn: () {},
                    onHistory: () {},
                    onRetry: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      return opened;
    }

    const verify = AttendanceDeviceStepException(
      isRegisteredDevice: true,
      step: AttendanceDeviceStep.verifyAtAttendance,
    );
    const notEnrolled = AttendanceDeviceStepException(
      isRegisteredDevice: false,
      step: AttendanceDeviceStep.notEnrolled,
    );

    testWidgets('an enrolled phone is sent to Absensi, not to HR', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(const SizedBox());
      opened = await pumpCard(tester, error: verify);

      expect(
        find.text('Buka Absensi untuk memverifikasi perangkat'),
        findsOneWidget,
      );
      expect(find.text('Perlu verifikasi'), findsOneWidget);
      expect(
        find.textContaining('Verifikasi berjalan otomatis'),
        findsOneWidget,
      );
      expect(find.textContaining('belum terdaftar'), findsNothing);
      expect(find.textContaining('Hubungi administrator'), findsNothing);
      expect(find.text('Izin absensi sesi ini terbatas'), findsNothing);

      expect(find.text('Buka Absensi'), findsOneWidget);
      expect(opened, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Buka Absensi" opens Absensi', (tester) async {
      var opened = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TodayWorkCard(
                state: HomeTodayState.unavailable,
                shiftName: null,
                scheduleIn: null,
                scheduleOut: null,
                timeIn: null,
                timeOut: null,
                lateMinutes: null,
                nextPunch: null,
                canClock: false,
                dayContext: null,
                error: verify,
                date: null,
                onClock: () => opened++,
                onSignIn: () {},
                onHistory: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Absensi'));
      expect(opened, 1);
    });

    testWidgets('no key: names the step and who to ask', (tester) async {
      await pumpCard(tester, error: notEnrolled);

      expect(find.text('Perangkat Absensi Belum Terdaftar'), findsOneWidget);
      expect(find.textContaining('Minta kode aktivasi ke HR'), findsOneWidget);
      expect(find.text('Buka Absensi'), findsOneWidget);
      expect(find.textContaining('Hubungi administrator'), findsNothing);
    });

    testWidgets('flag off: exactly the old card', (tester) async {
      await pumpCard(
        tester,
        error: const AttendanceAccessException(isRegisteredDevice: false),
      );

      expect(
        find.text('Perangkat belum terdaftar untuk absensi'),
        findsOneWidget,
      );
      expect(find.text('Buka Absensi'), findsNothing);
      expect(find.text('Perlu verifikasi'), findsNothing);
    });

    testWidgets('a recorded clock keeps its state and gets the true sentence', (
      tester,
    ) async {
      await pumpCard(tester, error: verify, state: HomeTodayState.working);

      expect(find.text('08:03'), findsOneWidget);
      expect(
        find.textContaining('Verifikasi berjalan otomatis'),
        findsOneWidget,
      );
      expect(find.textContaining('Hubungi administrator'), findsNothing);
    });

    for (final error in [verify, notEnrolled]) {
      testWidgets('${error.step.name} @320dp x2.0 does not overflow', (
        tester,
      ) async {
        await pumpCard(
          tester,
          error: error,
          size: const Size(320, 800),
          scale: 2.0,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
