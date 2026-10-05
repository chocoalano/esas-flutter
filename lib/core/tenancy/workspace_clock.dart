import '../utils/json_parsers.dart';

/// The clock the workspace runs on, and the only clock this app renders in.
///
/// ## The bug this exists to end
///
/// Every timestamp the API sends carries its own offset —
/// `2026-09-02T09:00:00+07:00` — so the *instant* is never ambiguous. Rendering
/// it is where it went wrong. Dart's `DateTime.parse` converts an offset-bearing
/// string to **UTC**, and this app then handed that straight to
/// `DateFormat(...).format(...)`, which formats whatever fields the object
/// carries. Nine in the morning in Jakarta was drawn as **02:00**, on the
/// activity feed, the notification list, attendance and permits alike.
///
/// `toLocal()` would have moved it — to the *phone's* zone, which is a different
/// wrong answer. A phone is not where the office is: a supervisor in Makassar
/// reading a Jakarta workspace, anybody whose handset follows them abroad, and
/// anybody who has ever set their clock by hand all get a different day boundary
/// from the one their attendance is recorded against.
///
/// So times are rendered in the **workspace's** zone, which the server now sends
/// with the session and with the pre-login workspace probe.
///
/// ## Why an offset and not a timezone database
///
/// Indonesia keeps three zones — WIB, WITA, WIT — and observes no daylight
/// saving. Each is therefore a constant offset from UTC, so an integer is an
/// exact answer rather than an approximation, and the app needs no `timezone`
/// package, no rule data, and nothing to keep up to date.
///
/// That is a fact about Indonesia, not a simplification. A deployment outside it
/// would need real zone data, and [WorkspaceClock] is where that would go.
class WorkspaceClock {
  const WorkspaceClock({
    required this.name,
    required this.abbreviation,
    required this.offsetMinutes,
  });

  /// What a handset falls back on before it has been told anything.
  ///
  /// WIB, because it is what the server defaults an unconfigured workspace to —
  /// so an app that has not yet read a session agrees with a server that has not
  /// yet been configured, rather than disagreeing by seven hours.
  factory WorkspaceClock.fallback() => const WorkspaceClock(
    name: 'Asia/Jakarta',
    abbreviation: 'WIB',
    offsetMinutes: 420,
  );

  /// Read the clock out of a `timezone` block, or fall back.
  ///
  /// Never throws and never returns null: a screen with no clock cannot draw a
  /// date at all, and refusing to draw is worse than drawing in the default the
  /// server itself would have used.
  factory WorkspaceClock.fromJson(Object? json) {
    final data = asObject(json);

    final offset = asInt(data['offset_minutes']);

    if (offset == null) {
      return WorkspaceClock.fallback();
    }

    return WorkspaceClock(
      name: asString(data['name']) ?? 'Asia/Jakarta',
      abbreviation: asString(data['abbreviation']) ?? 'WIB',
      offsetMinutes: offset,
    );
  }

  /// The clock every screen renders in.
  ///
  /// A process-wide value, like `Intl.defaultLocale`, and for the same reason:
  /// which zone to draw a time in is a property of the workspace this app is
  /// signed in to, not of the widget doing the drawing. Threading it through
  /// every constructor would put a parameter on code whose only crime is
  /// showing a date.
  ///
  /// Set from the session (`SessionRepository`) and from the pre-login
  /// workspace probe, so it is right before the first screen is built and stays
  /// right after a workspace switch. It falls back to WIB, which is what the
  /// server defaults an unconfigured workspace to — so the two agree rather than
  /// disagreeing by seven hours.
  static WorkspaceClock current = WorkspaceClock.fallback();

  /// The IANA name, e.g. `Asia/Makassar`. Carried for display and for the day
  /// somebody needs real zone data.
  final String name;

  /// `WIB`, `WITA` or `WIT` — how the time is written on everything else in the
  /// workspace, so a screen can label an hour the way a payslip does.
  final String abbreviation;

  /// Minutes ahead of UTC. 420, 480 or 540.
  final int offsetMinutes;

  Duration get offset => Duration(minutes: offsetMinutes);

  /// An instant, as the wall clock in the office reads it.
  ///
  /// The returned value is a UTC-flagged `DateTime` whose *fields* are the
  /// workspace's local time, which is the only way to hand a specific zone to
  /// `DateFormat` without a timezone database. It is a value to format, not a
  /// value to do arithmetic with — [instantOf] converts back.
  DateTime wallClock(DateTime instant) => instant.toUtc().add(offset);

  /// The instant a workspace wall-clock reading refers to.
  DateTime instantOf(DateTime wall) => DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
  ).subtract(offset);

  /// Now, on the workspace's clock.
  DateTime now() => wallClock(DateTime.now());

  /// Today, as the workspace reckons it.
  ///
  /// Which calendar day it is decides which roster row is "today" and whether a
  /// clock-in is late. Asking the handset would let a phone an hour either side
  /// of midnight disagree with the attendance record it is looking at.
  DateTime today() {
    final wall = now();

    return DateTime.utc(wall.year, wall.month, wall.day);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'abbreviation': abbreviation,
    'offset_minutes': offsetMinutes,
  };

  @override
  bool operator ==(Object other) =>
      other is WorkspaceClock &&
      other.name == name &&
      other.abbreviation == abbreviation &&
      other.offsetMinutes == offsetMinutes;

  @override
  int get hashCode => Object.hash(name, abbreviation, offsetMinutes);

  @override
  String toString() => 'WorkspaceClock($name, $abbreviation, $offsetMinutes)';
}
