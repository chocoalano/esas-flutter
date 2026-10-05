import 'package:esas/features/attendance/data/models/attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a complete row', () {
    final a = Attendance.fromJson({
      'id': 12,
      'user_id': 7,
      'time_in': '08:01:00',
      'time_out': '17:05:00',
      'status_in': 'late',
      'date_presence': '2026-08-31',
      'created_at': '2026-08-31T01:01:00.000Z',
    });

    expect(a.id, 12);
    expect(a.timeIn, '08:01:00');
    expect(a.statusIn, 'late');
    expect(a.createdAt?.year, 2026);
  });

  test('survives the nulls the backend actually sends', () {
    // A row for a day somebody has clocked in but not out. The previous parser
    // called DateTime.parse on a null and took the whole screen with it.
    final a = Attendance.fromJson({
      'id': 12,
      'time_in': '08:01:00',
      'time_out': null,
      'status_out': null,
      'created_at': null,
      'user': null,
    });

    expect(a.timeOut, isNull);
    expect(a.statusOut, isNull);
    expect(a.createdAt, isNull);
    expect(a.user, isNull);
  });

  test('survives an entirely empty row without throwing', () {
    expect(() => Attendance.fromJson(const {}), returnsNormally);
  });

  test('accepts an id sent as a string', () {
    expect(Attendance.fromJson({'id': '12'}).id, 12);
  });

  test('does not throw on a malformed date, it drops it', () {
    // Visibly empty beats plausible-but-wrong on an attendance record (R-10).
    expect(Attendance.fromJson({'created_at': 'yesterday'}).createdAt, isNull);
  });
}
