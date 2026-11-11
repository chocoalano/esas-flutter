import 'dart:convert';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/features/attendance/data/models/scanned_code.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/presentation/attendance_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ATTP-19. `UNLATE` had a label but was not in the set of known codes, so
  // the home timeline printed the raw code.
  test('UNLATE is a known status code', () {
    expect(
      attendanceStatusCodeLabel('unlate'),
      attendanceStatusLabel('UNLATE'),
    );
    expect(attendanceStatusCodeLabel('unlate'), isNot('unlate'));
  });

  // ATTD-06. An `exp` far outside the representable range threw a RangeError
  // out of a method documented never to throw, ten times a second.
  test('an absurd expiry is no expiry, not a crash', () {
    String machine(Object exp) {
      final segment = base64Url
          .encode(utf8.encode(json.encode({'jti': 'x', 'exp': exp})))
          .replaceAll('=', '');
      return '$segment.sig';
    }

    expect(
      () => ScannedCode.recognise(machine(9000000000000)),
      returnsNormally,
    );
    final code = ScannedCode.recognise(machine(9000000000000));
    expect(code, isA<MachineCode>());
    expect((code! as MachineCode).expiresAt, isNull);
  });

  // ATTD-05. A suspended workspace (423) and a rate limit (429) were filed as
  // "clock rejected — contact HR", with the server's sentence thrown away.
  group('refusals that are not about the employee', () {
    test('a suspended workspace keeps the server\'s sentence', () {
      final refusal = AttendanceRepository.refusalFor(
        const ApiException(
          'Workspace sedang ditangguhkan oleh platform.',
          status: 423,
          code: 'tenant_suspended',
        ),
      );

      expect(refusal.message, 'Workspace sedang ditangguhkan oleh platform.');
      expect(refusal.message, isNot(contains('Hubungi HR')));
      expect(refusal.kind, isNot(RefusalKind.clockRejected));
    });

    test('a rate limit is a try-again', () {
      final refusal = AttendanceRepository.refusalFor(
        const ApiException('Too Many Attempts.', status: 429),
      );

      expect(refusal.kind, RefusalKind.transient);
      expect(refusal.message, isNot(contains('Too Many')));
    });
  });

  // ATTP-20. Days counted with `subtract(Duration(days: n))` across a DST
  // change land on 23:00 of the day before. Run with
  // `TZ=Europe/Amsterdam flutter test` to see it on a development machine.
  test('the strip is seven calendar days, whatever the zone does', () {
    final days = attendanceStripDays(
      anchor: DateTime(2026, 4, 2),
      windowStart: DateTime(2026, 3, 1),
      maxDays: 7,
    );

    expect(days, hasLength(7));
    for (var i = 0; i < days.length; i++) {
      final expected = DateTime(2026, 3, 27 + i);
      expect(
        [days[i].year, days[i].month, days[i].day],
        [expected.year, expected.month, expected.day],
        reason: 'day $i',
      );
    }
  });

  // ATTP-16. A night shift dated yesterday, still before its end this morning,
  // was marked "Belum lengkap" in the history.
  group('a night shift past midnight', () {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    test('is still running before its end', () {
      final now = WorkspaceClock.current.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      // An end later than now today, so the shift is not over yet.
      final endMinutes = now.hour * 60 + now.minute + 60;
      if (endMinutes >= 24 * 60) return; // too close to midnight to say.
      final shiftOut =
          '${(endMinutes ~/ 60).toString().padLeft(2, '0')}:'
          '${(endMinutes % 60).toString().padLeft(2, '0')}';

      expect(
        attendanceGapOf(
          timeIn: '22:00',
          timeOut: null,
          datePresence: ymd(yesterday),
          crossesMidnight: true,
          shiftOut: shiftOut,
        ),
        AttendanceGap.running,
      );
    });

    test('is missing a clock-out once its end has passed', () {
      final now = WorkspaceClock.current.now();
      final twoDaysAgo = DateTime(now.year, now.month, now.day - 2);

      expect(
        attendanceGapOf(
          timeIn: '22:00',
          timeOut: null,
          datePresence: ymd(twoDaysAgo),
          crossesMidnight: true,
          shiftOut: '06:00',
        ),
        AttendanceGap.missing,
      );
    });
  });
}
