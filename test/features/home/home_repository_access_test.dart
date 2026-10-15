import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/data/services/home_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements HomeApiService {}

class _MockSession extends Mock implements SessionRepository {}

void main() {
  late _MockApi api;
  late _MockSession session;
  late HomeRepository repository;

  void signInWith(Map<String, dynamic> fields) {
    when(() => session.user).thenReturn(AuthUser.fromJson(fields));
  }

  setUp(() {
    api = _MockApi();
    session = _MockSession();
    repository = HomeRepository(api: api, session: session);
    when(() => api.attendanceContext()).thenAnswer(
      (_) async => {
        'attendance': {'time_in': '08:03'},
      },
    );
  });

  test('employee with attendance disabled does not request context', () async {
    signInWith({
      'attendance_enabled': false,
      'device': {'can_record_attendance': false},
    });

    final times = await repository.todayAttendance();

    expect(times.attendanceEnabled, isFalse);
    verifyNever(() => api.attendanceContext());
  });

  test('unregistered device is explained before the denied request', () async {
    signInWith({
      'attendance_enabled': true,
      'abilities': ['self-service'],
      'device': {'can_record_attendance': false, 'is_registered_device': false},
    });

    await expectLater(
      repository.todayAttendance(),
      throwsA(
        isA<AttendanceAccessException>()
            .having((error) => error.isRegisteredDevice, 'device', false)
            .having((error) => error.status, 'status', 403)
            .having(
              (error) => error.code,
              'code',
              'attendance_device_unregistered',
            ),
      ),
    );
    verifyNever(() => api.attendanceContext());
  });

  test('missing token ability does not claim the device is wrong', () async {
    signInWith({
      'attendance_enabled': true,
      'abilities': ['self-service'],
      'device': {'is_registered_device': true},
    });

    await expectLater(
      repository.todayAttendance(),
      throwsA(
        isA<AttendanceAccessException>()
            .having((error) => error.isRegisteredDevice, 'device', true)
            .having(
              (error) => error.code,
              'code',
              'attendance_access_restricted',
            )
            .having(
              (error) => error.message,
              'message',
              contains('izin absensi'),
            ),
      ),
    );
    verifyNever(() => api.attendanceContext());
  });

  test(
    'legacy session without capability metadata still requests context',
    () async {
      signInWith({'attendance_enabled': true});

      final times = await repository.todayAttendance();

      expect(times.timeIn, '08:03');
      expect(times.attendanceEnabled, isTrue);
      verify(() => api.attendanceContext()).called(1);
    },
  );

  test(
    'allowed device requests context and honors its disabled flag',
    () async {
      signInWith({
        'attendance_enabled': true,
        'device': {'can_record_attendance': true},
      });
      when(
        () => api.attendanceContext(),
      ).thenAnswer((_) async => {'attendance_enabled': false});

      expect((await repository.todayAttendance()).attendanceEnabled, isFalse);
      verify(() => api.attendanceContext()).called(1);
    },
  );
}
