import 'package:esas/features/attendance/data/models/attendance_context.dart';
import 'package:flutter_test/flutter_test.dart';

/// What `GET /attendance/context` answers, and what the screen may conclude
/// from it.
///
/// Every capability the attendance screen draws comes from this payload, and
/// none is invented in Dart. The three that decide what an employee can even
/// see are `attendance_enabled`, `face_enrolled` and `next_presence`; the
/// fourth, `location`, replaces reading company coordinates out of a cached
/// login user that `tenancy-app` no longer sends — which is why the scanner
/// used to lock itself with "Titik absensi belum diatur" for everybody.
void main() {
  Map<String, dynamic> body({
    Object? attendanceEnabled,
    Object? qrEnabled,
    Object? faceEnrolled,
    Object? nextPresence = 'in',
    Object? location,
    Object? schedule,
  }) => <String, dynamic>{
    'server_time': '2026-09-04T08:00:00+07:00',
    if (attendanceEnabled != null) 'attendance_enabled': attendanceEnabled,
    if (qrEnabled != null) 'qr_enabled': qrEnabled,
    if (faceEnrolled != null) 'face_enrolled': faceEnrolled,
    'next_presence': nextPresence,
    if (location != null) 'location': location,
    if (schedule != null) 'schedule': schedule,
  };

  group('attendance_enabled — silence is not a refusal', () {
    test('null is treated as permitted', () {
      // An installation that has never sent the flag is not forbidding anybody.
      // Reading its absence as `false` would hide the only way to clock in from
      // every employee on that deployment.
      final context = AttendanceContext.fromJson(body());

      expect(context.attendanceEnabled, isNull);
      expect(context.canClock, isTrue);
    });

    test('only an explicit false withholds attendance', () {
      expect(
        AttendanceContext.fromJson(body(attendanceEnabled: false)).canClock,
        isFalse,
      );
      expect(
        AttendanceContext.fromJson(body(attendanceEnabled: true)).canClock,
        isTrue,
      );
    });
  });

  group('qr_enabled — a TRISTATE, and null is not false', () {
    test('absent reads as unknown, and unknown stays attemptable', () {
      // The field is new. Every deployment that predates it sends nothing, and
      // reading that silence as a refusal would hide the only method most
      // employees have from every handset talking to an older server.
      final context = AttendanceContext.fromJson(body());

      expect(context.qrEnabled, isNull);
      expect(context.canUseQr, isTrue);
    });

    test('an explicit false withholds QR', () {
      final context = AttendanceContext.fromJson(body(qrEnabled: false));

      expect(context.qrEnabled, isFalse);
      expect(context.canUseQr, isFalse);
    });

    test('an explicit true allows it', () {
      expect(
        AttendanceContext.fromJson(body(qrEnabled: true)).canUseQr,
        isTrue,
      );
    });

    test('attendance_enabled: false outranks qr_enabled: true', () {
      // An account that may not clock at all may not clock by QR either. The
      // two switches are not peers — one is about the person, the other about
      // the company's methods.
      final context = AttendanceContext.fromJson(
        body(attendanceEnabled: false, qrEnabled: true),
      );

      expect(context.canUseQr, isFalse);
    });
  });

  group('the four method combinations', () {
    ({bool qr, bool face}) methods({Object? qrEnabled, Object? faceEnrolled}) {
      final context = AttendanceContext.fromJson(
        body(qrEnabled: qrEnabled, faceEnrolled: faceEnrolled),
      );

      return (qr: context.canUseQr, face: context.canUseFace);
    }

    test('both', () {
      expect(methods(qrEnabled: true, faceEnrolled: true), (
        qr: true,
        face: true,
      ));
    });

    test('QR only', () {
      expect(methods(qrEnabled: true, faceEnrolled: false), (
        qr: true,
        face: false,
      ));
    });

    test('face only', () {
      expect(methods(qrEnabled: false, faceEnrolled: true), (
        qr: false,
        face: true,
      ));
    });

    test('neither', () {
      expect(methods(qrEnabled: false, faceEnrolled: false), (
        qr: false,
        face: false,
      ));
    });
  });

  group('backward and forward compatibility', () {
    test('a payload from an older backend still parses', () {
      // No `qr_enabled`, no `location`, no `schedule` — the shape a deployment
      // that predates this work answers with. It must not throw, and it must not
      // silently forbid anything.
      final context = AttendanceContext.fromJson(const {
        'server_time': '2026-09-04T08:00:00+07:00',
        'attendance_enabled': true,
        'face_enrolled': false,
        'next_presence': 'in',
      });

      expect(context.canClock, isTrue);
      expect(context.canUseQr, isTrue);
      expect(context.qrEnabled, isNull);
      expect(context.geofence.required_, isFalse);
    });

    test('a field this build has never heard of is ignored', () {
      // The server is free to grow. A client that threw on an unknown key would
      // be a client that breaks on the next backend release.
      final context = AttendanceContext.fromJson(const {
        'attendance_enabled': true,
        'qr_enabled': true,
        'fingerprint_enabled': true,
        'some_future_block': {
          'nested': [1, 2, 3],
        },
      });

      expect(context.canUseQr, isTrue);
    });

    test('a null where a bool was expected is not a false', () {
      expect(
        AttendanceContext.fromJson(const {'qr_enabled': null}).qrEnabled,
        isNull,
      );
    });
  });

  group('face_enrolled — absent means not enrolled', () {
    test('defaults to false', () {
      // The opposite default would offer a face button to somebody with no
      // reference photographs on file, and the only thing behind it is a 409.
      expect(AttendanceContext.fromJson(body()).faceEnrolled, isFalse);
    });

    test('is read when sent', () {
      expect(
        AttendanceContext.fromJson(body(faceEnrolled: true)).faceEnrolled,
        isTrue,
      );
    });
  });

  group('next_presence — read loosely, judged strictly', () {
    test('accepts the bare string', () {
      expect(
        AttendanceContext.fromJson(body(nextPresence: 'out')).nextPresence,
        PresenceDirection.clockOut,
      );
    });

    test('accepts the object form the flag has also been sent as', () {
      expect(
        AttendanceContext.fromJson(
          body(nextPresence: {'type': 'in'}),
        ).nextPresence,
        PresenceDirection.clockIn,
      );
    });

    test('anything else is null, and null is not a guess', () {
      // Guessing the wrong direction costs more than not knowing: it writes
      // "Absen pulang" above somebody who has not clocked in yet, and on a
      // machine code — which carries no direction of its own — it would ask the
      // server to close a shift that was never opened.
      for (final raw in <Object?>[null, '', 'masuk', 'inside', 7, <String>[]]) {
        expect(
          AttendanceContext.fromJson(body(nextPresence: raw)).nextPresence,
          isNull,
          reason: 'should not read a direction from: $raw',
        );
      }
    });

    test('case and stray whitespace are tolerated', () {
      // Loose about shape, strict about value: `"IN "` is the same answer as
      // `"in"`, and refusing it would be refusing a clock over a space.
      expect(
        AttendanceContext.fromJson(body(nextPresence: 'IN ')).nextPresence,
        PresenceDirection.clockIn,
      );
    });

    test('a day with nothing left to clock is complete, not broken', () {
      final context = AttendanceContext.fromJson(body(nextPresence: null));

      expect(context.nextPresence, isNull);
      expect(context.dayComplete, isTrue);
    });
  });

  group('location', () {
    test('a workspace with no geofence asks the handset for nothing', () {
      final context = AttendanceContext.fromJson(
        body(location: {'required': false}),
      );

      expect(context.geofence.required_, isFalse);
      expect(context.geofence.hasCentre, isFalse);
    });

    test('a geofenced workspace carries centre and radius', () {
      final context = AttendanceContext.fromJson(
        body(
          location: {
            'required': true,
            'latitude': -6.2,
            'longitude': 106.8,
            'radius_metres': 50,
          },
        ),
      );

      expect(context.geofence.required_, isTrue);
      expect(context.geofence.hasCentre, isTrue);
      expect(context.geofence.radiusMetres, 50);
    });

    test('required with no centre is still required', () {
      // Nothing on the handset can pre-empt this: the coordinates go up and the
      // server decides, which beats refusing a clock over a configuration the
      // employee cannot see, let alone fix.
      final context = AttendanceContext.fromJson(
        body(location: {'required': true}),
      );

      expect(context.geofence.required_, isTrue);
      expect(context.geofence.hasCentre, isFalse);
    });

    test('a missing location block is not a geofence', () {
      expect(AttendanceContext.fromJson(body()).geofence.required_, isFalse);
    });
  });

  group('schedule', () {
    test('is read when the roster has one', () {
      final shift = AttendanceContext.fromJson(
        body(
          schedule: {
            'shift': 'Shift Pagi',
            'in': '08:00:00',
            'out': '17:00:00',
            'crosses_midnight': false,
          },
        ),
      ).shift;

      expect(shift, isNotNull);
      expect(shift!.name, 'Shift Pagi');
      expect(shift.hasHours, isTrue);
    });

    test('a night shift is marked as crossing midnight', () {
      final shift = AttendanceContext.fromJson(
        body(
          schedule: {
            'shift': 'Shift Malam',
            'in': '22:00',
            'out': '06:00',
            'crosses_midnight': true,
          },
        ),
      ).shift;

      expect(shift!.crossesMidnight, isTrue);
    });

    test('an empty or absent schedule is null, not an empty shift', () {
      // A blank subtitle is better than "  –  " under the page title.
      expect(AttendanceContext.fromJson(body()).shift, isNull);
      expect(
        AttendanceContext.fromJson(body(schedule: <String, dynamic>{})).shift,
        isNull,
      );
    });
  });

  group('the schedule block, as the server sends it', () {
    // Copied from a real `GET /attendance/context` answer for a night shift.
    // Thirteen keys, because that is what the contract has; the client read
    // four of them and inferred the rest.
    Map<String, dynamic> nightShift() => <String, dynamic>{
      'id': 4021,
      'work_day': '2026-09-06',
      'shift': 'Shift 3',
      'in': '23:00:00',
      'out': '07:00:00',
      'crosses_midnight': true,
      'code': 'SHIFT_3',
      'name': 'Shift 3 (Malam)',
      'roster_date': '2026-09-06',
      'starts_at': '2026-09-06T23:00:00+07:00',
      'ends_at': '2026-09-07T07:00:00+07:00',
      'spans_midnight': true,
      'closing_grace_hours': 2.0,
    };

    test('reads every field the contract carries', () {
      final shift = AttendanceShift.fromJson(nightShift())!;

      expect(shift.code, 'SHIFT_3');
      expect(shift.name, 'Shift 3 (Malam)');
      expect(shift.start, '23:00:00');
      expect(shift.end, '07:00:00');
      expect(shift.crossesMidnight, isTrue);
      expect(shift.rosterDate, DateTime.parse('2026-09-06'));
      expect(shift.startsAt, isNotNull);
      expect(shift.endsAt, isNotNull);
      expect(shift.closingGraceHours, 2.0);

      // The end is on the following date, which is the fact two `HH:mm`
      // strings cannot carry.
      expect(shift.endsAt!.isAfter(shift.startsAt!), isTrue);
    });

    test('says the day out loud rather than leaving it to be inferred', () {
      final shift = AttendanceShift.fromJson(nightShift())!;

      expect(shift.hoursLabel, '23:00–07:00 (+1 hari)');
    });

    test('an ordinary day shift carries no day marker', () {
      final shift = AttendanceShift.fromJson(<String, dynamic>{
        'shift': 'Shift 1',
        'name': 'Shift 1 (Pagi)',
        'in': '07:00:00',
        'out': '15:00:00',
        'spans_midnight': false,
        'crosses_midnight': false,
      })!;

      expect(shift.hoursLabel, '07:00–15:00');
      expect(shift.crossesMidnight, isFalse);
    });

    test('prefers the server\'s spans_midnight over the older key', () {
      // A deployment that sends both, disagreeing. `spans_midnight` is the
      // canonical one and the older key is only a fallback.
      final shift = AttendanceShift.fromJson(<String, dynamic>{
        'shift': 'Shift 3',
        'in': '23:00',
        'out': '07:00',
        'spans_midnight': true,
        'crosses_midnight': false,
      })!;

      expect(shift.crossesMidnight, isTrue);
    });

    test('falls back to the older key for a deployment without the new one', () {
      final shift = AttendanceShift.fromJson(<String, dynamic>{
        'shift': 'Shift 3',
        'in': '23:00',
        'out': '07:00',
        'crosses_midnight': true,
      })!;

      expect(shift.crossesMidnight, isTrue);
      // And nothing is invented for the fields it does not send.
      expect(shift.startsAt, isNull);
      expect(shift.code, isNull);
    });

    test('never guesses the crossing from end < start', () {
      // `06:00` before `23:00` looks like a night shift to a string compare.
      // The server is the only thing that knows, and it said no.
      final shift = AttendanceShift.fromJson(<String, dynamic>{
        'shift': 'Aneh',
        'in': '23:00',
        'out': '06:00',
        'spans_midnight': false,
      })!;

      expect(shift.crossesMidnight, isFalse);
      expect(shift.hoursLabel, '23:00–06:00');
    });
  });
}
