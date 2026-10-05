import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Times belong to the workspace, not to the handset.
///
/// The bug these pin was silent and total. Every timestamp the API sends carries
/// its offset — `2026-09-02T09:00:00+07:00` — and Dart's `DateTime.parse`
/// converts that to **UTC**. The app then handed the result straight to
/// `DateFormat.format`, which draws whatever fields the object carries. Nine in
/// the morning in Jakarta was shown as **02:00** on the activity feed, the
/// notification list and the home screen alike, and it looked plausible enough
/// that nobody would call it a parsing error.
///
/// `toLocal()` is not the repair. It renders in the phone's zone, which is a
/// different wrong answer the moment the phone is not in the office.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('id');
  });

  setUp(() {
    WorkspaceClock.current = WorkspaceClock.fallback();
  });

  group('reading the clock the server sent', () {
    test('takes the workspace zone', () {
      final clock = WorkspaceClock.fromJson({
        'name': 'Asia/Makassar',
        'abbreviation': 'WITA',
        'offset_minutes': 480,
      });

      expect(clock.abbreviation, 'WITA');
      expect(clock.offsetMinutes, 480);
    });

    test('falls back to WIB when a server predates the field', () {
      // The value that server was itself running on, so the two agree rather
      // than disagreeing by seven hours.
      final clock = WorkspaceClock.fromJson(null);

      expect(clock.name, 'Asia/Jakarta');
      expect(clock.offsetMinutes, 420);
      expect(clock, WorkspaceClock.fallback());
    });

    test('a malformed block is a fallback, not a crash', () {
      // A screen with no clock cannot draw a date at all.
      expect(WorkspaceClock.fromJson('nonsense'), WorkspaceClock.fallback());
      expect(WorkspaceClock.fromJson(const {}), WorkspaceClock.fallback());
    });
  });

  group('rendering an instant', () {
    test('draws it on the workspace clock, not in UTC', () {
      WorkspaceClock.current = WorkspaceClock.fromJson({
        'name': 'Asia/Jakarta',
        'abbreviation': 'WIB',
        'offset_minutes': 420,
      });

      // Exactly what the API sends, and exactly what used to render as 02:00.
      final instant = DateTime.parse('2026-09-02T09:00:00+07:00');

      expect(DateFormatter.timestamp(instant, 'HH:mm'), '09:00');
      expect(
        DateFormatter.timestamp(instant, 'd MMM yyyy • HH:mm'),
        '2 Sep 2026 • 09:00',
      );
    });

    test('the same instant reads differently in a different workspace', () {
      final instant = DateTime.parse('2026-09-02T09:00:00+07:00');

      WorkspaceClock.current = const WorkspaceClock(
        name: 'Asia/Jayapura',
        abbreviation: 'WIT',
        offsetMinutes: 540,
      );

      // One moment, two offices. This is the case a handset could never get
      // right on its own, because the only zone it knows is its own.
      expect(DateFormatter.timestamp(instant, 'HH:mm'), '11:00');
    });

    test('an absent timestamp is a dash, not an exception', () {
      expect(DateFormatter.timestamp(null, 'HH:mm'), '-');
    });

    test('a date with no zone is left where it is', () {
      // A birthday means the same calendar day everywhere; giving it a zone is
      // how it moves a day.
      expect(DateFormatter.dayMonthYear('1995-01-20'), '20 Januari 1995');
    });
  });

  group('now, and today', () {
    test('an instant survives the round trip', () {
      const clock = WorkspaceClock(
        name: 'Asia/Makassar',
        abbreviation: 'WITA',
        offsetMinutes: 480,
      );

      final instant = DateTime.parse('2026-09-02T01:30:00Z');

      expect(clock.instantOf(clock.wallClock(instant)), instant);
    });

    test('today is the office\'s day, not the handset\'s', () {
      const clock = WorkspaceClock(
        name: 'Asia/Jayapura',
        abbreviation: 'WIT',
        offsetMinutes: 540,
      );

      // 23:30 UTC is already the next morning in Jayapura. Which calendar day
      // it is decides which roster row is "today" and whether a clock-in is
      // late, so asking the handset lets a phone disagree with the attendance
      // record it is looking at.
      final wall = clock.wallClock(DateTime.parse('2026-09-02T23:30:00Z'));

      expect(wall.day, 3);
      expect(wall.hour, 8);
    });
  });
}
