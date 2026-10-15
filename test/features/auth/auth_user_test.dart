import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('attendance session capability', () {
    test('missing capability fields remain unknown', () {
      final user = AuthUser.fromJson({'attendance_enabled': true});

      expect(user.attendanceEnabled, isTrue);
      expect(user.canRecordAttendance, isNull);
      expect(user.isRegisteredDevice, isNull);
    });

    test('device decision takes precedence over token abilities', () {
      final user = AuthUser.fromJson({
        'attendance_enabled': true,
        'abilities': ['attendance'],
        'device': {
          'can_record_attendance': false,
          'is_registered_device': false,
        },
      });

      expect(user.attendanceEnabled, isTrue);
      expect(user.canRecordAttendance, isFalse);
      expect(user.isRegisteredDevice, isFalse);
    });

    test('known abilities distinguish attendance and self-service access', () {
      for (final abilities in [
        <String>['self-service'],
        <String>[],
      ]) {
        expect(
          AuthUser.fromJson({'abilities': abilities}).canRecordAttendance,
          isFalse,
        );
      }
      for (final abilities in [
        ['attendance'],
        ['*'],
      ]) {
        expect(
          AuthUser.fromJson({'abilities': abilities}).canRecordAttendance,
          isTrue,
        );
      }
    });

    test('malformed abilities do not establish a denial', () {
      expect(
        AuthUser.fromJson({'abilities': 'attendance'}).canRecordAttendance,
        isNull,
      );
      expect(
        AuthUser.fromJson({
          'abilities': [null],
        }).canRecordAttendance,
        isNull,
      );
    });

    test('legacy flat device flags are supported', () {
      final user = AuthUser.fromJson({
        'can_record_attendance': false,
        'is_registered_device': true,
      });

      expect(user.canRecordAttendance, isFalse);
      expect(user.isRegisteredDevice, isTrue);
    });
  });
}
