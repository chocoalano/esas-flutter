import '../../../../core/utils/json_parsers.dart';

/// Which clock this person still owes.
enum PresenceDirection {
  /// Absen masuk.
  clockIn('in', 'Absen masuk'),

  /// Absen pulang.
  clockOut('out', 'Absen pulang');

  const PresenceDirection(this.wire, this.label);

  /// What the server calls it, and what goes back in `type`.
  final String wire;

  /// What the screen calls it, in Indonesian.
  final String label;

  /// Read `next_presence`, loosely about shape and strictly about value.
  ///
  /// The flag has been sent as a bare string (`"in"`) and as an object
  /// (`{"type": "in"}`), so both are accepted; anything that does not produce
  /// one of the two words is `null`, and `null` means the app does not know.
  /// Guessing the wrong direction costs more than not knowing: it writes "Absen
  /// pulang" above somebody who has not clocked in yet.
  static PresenceDirection? parse(Object? raw) {
    final Object? value = raw is Map
        ? asObject(raw)['type'] ?? raw['direction']
        : raw;
    final String? text = asString(value)?.trim().toLowerCase();

    return switch (text) {
      'in' => PresenceDirection.clockIn,
      'out' => PresenceDirection.clockOut,
      _ => null,
    };
  }
}

/// What the company expects of a clock's coordinates.
///
/// Read from `attendance/context` rather than from the cached login user, which
/// is gap G-1: the `tenancy-app` login payload flattens `company` to a name, so
/// `AuthUser.companyLatitude` is null on every real installation and the scanner
/// used to lock itself with "Titik absensi belum diatur" for everybody.
class AttendanceGeofence {
  const AttendanceGeofence({
    required this.required_,
    this.latitude,
    this.longitude,
    this.radiusMetres,
  });

  /// Whether the company checks where a clock came from at all.
  ///
  /// Named with a trailing underscore because `required` is a keyword. The
  /// awkwardness is worth one field: `enabled` would be a second word for a
  /// thing the server already has a name for.
  final bool required_;

  final double? latitude;
  final double? longitude;
  final double? radiusMetres;

  /// Whether there is a centre to measure a distance against.
  ///
  /// A company that requires location but has no coordinates on file is a
  /// configuration the server can still refuse a clock for; the app cannot
  /// pre-empt it, and says so rather than blaming the employee.
  bool get hasCentre => latitude != null && longitude != null;

  static AttendanceGeofence fromJson(Object? raw) {
    final data = asObject(raw);

    return AttendanceGeofence(
      required_: asBool(data['required']) ?? false,
      latitude: asDouble(data['latitude']),
      longitude: asDouble(data['longitude']),
      radiusMetres: asDouble(data['radius_metres']),
    );
  }
}

/// The rostered shift, as the attendance screen shows it.
///
/// ## Every field the server sends, not the four it used to read
///
/// `schedule` carries thirteen keys and this model read four of them: `shift`,
/// `in`, `out` and `crosses_midnight`. The nine it dropped are the ones that
/// make a night shift drawable — `starts_at` and `ends_at` are real moments a
/// day apart, `spans_midnight` is the server's own answer to the question the
/// screen was left to infer, and `roster_date` is the day payroll, overtime and
/// the attendance row all key off.
///
/// Reading two `HH:mm` strings and nothing else is why a shift ending at 07:00
/// looked like it had ended fifteen hours ago.
class AttendanceShift {
  const AttendanceShift({
    this.name,
    this.start,
    this.end,
    this.crossesMidnight = false,
    this.code,
    this.rosterDate,
    this.startsAt,
    this.endsAt,
    this.closingGraceHours,
  });

  final String? name;

  /// `HH:mm` or `HH:mm:ss`, verbatim from the server.
  final String? start;
  final String? end;

  /// True for a shift that ends on the following date, so the screen can write
  /// "sampai besok 06:00" rather than an end that reads as the past.
  ///
  /// Read from `spans_midnight`, which is the server's canonical answer, and
  /// from `crosses_midnight` only as a fallback for a deployment that predates
  /// it. Never computed here from `end < start`: that comparison is on two
  /// strings, and it is the reason a shift stored as `6:00` once read as
  /// crossing midnight when it did not.
  final bool crossesMidnight;

  /// The shift's short code, as the roster names it.
  final String? code;

  /// The roster day this shift belongs to. At 01:00 a night worker is still on
  /// the shift that began yesterday, and this is that date.
  final DateTime? rosterDate;

  /// Real moments, not times of day: `23:00 → 07:00` arrives as two datetimes a
  /// day apart, so the screen can count down to the end of a shift without
  /// re-deriving which calendar day the end belongs to.
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// How long after [endsAt] a clock-out is still accepted, so the screen can
  /// say "masih bisa absen pulang sampai 09:00" instead of offering a button
  /// that answers 409.
  final double? closingGraceHours;

  bool get hasHours => start != null && end != null;

  /// The hours as somebody reads them, with the day the end falls on.
  ///
  /// `23:00–07:00 (+1 hari)`. The suffix is the whole point: without it the end
  /// reads as a time earlier today, which is the past.
  String? get hoursLabel {
    if (!hasHours) return null;

    final hours = '${_hhmm(start!)}–${_hhmm(end!)}';

    return crossesMidnight ? '$hours (+1 hari)' : hours;
  }

  /// `08:00:00` and `08:00` both read as `08:00`. The seconds are noise on a
  /// shift boundary.
  static String _hhmm(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

  static AttendanceShift? fromJson(Object? raw) {
    if (raw == null) return null;

    final data = asObject(raw);

    if (data.isEmpty) return null;

    final shift = AttendanceShift(
      // `name` is the fuller label the contract added; `shift` is the original
      // key and still the fallback for a deployment that sends only it.
      name: asString(data['name']) ?? asString(data['shift']),
      start: asString(data['in']),
      end: asString(data['out']),
      crossesMidnight:
          asBool(data['spans_midnight']) ??
          asBool(data['crosses_midnight']) ??
          false,
      code: asString(data['code']),
      rosterDate: asDate(data['roster_date']) ?? asDate(data['work_day']),
      startsAt: asDate(data['starts_at']),
      endsAt: asDate(data['ends_at']),
      closingGraceHours: asDouble(data['closing_grace_hours']),
    );

    return shift.name == null && !shift.hasHours ? null : shift;
  }
}

/// Everything the attendance screen would otherwise have to guess.
///
/// One request, `GET /attendance/context`, and it is the same one Beranda
/// already makes — not a new endpoint invented so a header could have a
/// subtitle. What it answers is what decides which methods the screen may
/// offer at all:
///
/// * [attendanceEnabled] — whether this account may clock **at all**;
/// * [faceEnrolled] — whether HR has registered this person's face, which is
///   the only thing that makes the wajah method usable;
/// * [nextPresence] — masuk or pulang, decided by the roster and not by the
///   handset guessing from a clock it can read;
/// * [geofence] — where from, and how far is too far.
///
/// * [qrEnabled] / [faceEnabled] — whether the company has each method
///   switched on, from the workspace's own `settings` row;
///
/// **A button that can only fail is worse than no button**, and every one of
/// these is answered before the screen is drawn. What the app must never do is
/// invent a capability the server does not send: [qrEnabled] is a **tristate**
/// for exactly that reason, and a deployment that has never heard of the field
/// leaves QR attemptable with the server as authority — the behaviour that
/// shipped before it existed.
class AttendanceContext {
  const AttendanceContext({
    this.attendanceEnabled,
    this.qrEnabled,
    this.faceEnabled,
    this.faceEnrolled = false,
    this.canIssueQr = false,
    this.nextPresence,
    this.geofence = const AttendanceGeofence(required_: false),
    this.shift,
    this.serverTime,
  });

  /// Whether HR has put this account on attendance.
  ///
  /// `null` means the server did not say, and that is **not** `false`: an
  /// installation that has never sent the flag is not forbidding anybody. Read
  /// through [canClock], which treats the silence as permission.
  final bool? attendanceEnabled;

  /// Whether the company has QR attendance switched on.
  ///
  /// **Three values, and `null` is not `false`.** A backend that predates this
  /// field sends nothing, and reading that silence as a refusal would hide the
  /// only method most employees have from every handset talking to an older
  /// deployment. `null` means *unknown* — the method stays attemptable and the
  /// server remains the authority, which is exactly the behaviour that shipped
  /// before the field existed.
  ///
  /// Sourced server-side from `KioskSettings::allowsQr()` — the same policy the
  /// QR endpoints consult, not a second copy of it.
  final bool? qrEnabled;

  /// Whether the company has face attendance switched on.
  ///
  /// A **different question** from [faceEnrolled], and conflating them tells an
  /// enrolled employee that their enrolment is missing. One is the company's
  /// setting; the other is HR's record about this person.
  ///
  /// Tristate for the same reason as [qrEnabled]: `null` means a deployment that
  /// does not send the field, and that is not a refusal.
  final bool? faceEnabled;

  /// Whether this person has usable reference photographs on file.
  ///
  /// Enrolment is done by HR in the panel, not in this app. Until it is done
  /// the wajah method is *not yet available* — which is a different sentence
  /// from an error, and gets a different screen.
  final bool faceEnrolled;

  /// Whether this person may issue department QR codes. Read, not acted on:
  /// this app has no issuing screen, and a `true` here is not a reason to grow
  /// one.
  final bool canIssueQr;

  final PresenceDirection? nextPresence;

  final AttendanceGeofence geofence;

  final AttendanceShift? shift;

  /// The workspace's own clock at the moment it answered.
  final DateTime? serverTime;

  /// Whether the account is allowed to record attendance.
  ///
  /// Only an explicit `false` withholds it. See [attendanceEnabled].
  bool get canClock => attendanceEnabled != false;

  /// Whether QR may be attempted. Only an explicit `false` withholds it.
  bool get canUseQr => canClock && qrEnabled != false;

  /// Whether the face method may be attempted.
  ///
  /// Three conditions, and each is a different sentence on screen: the account
  /// may clock at all, the company allows the method, and HR has enrolled this
  /// person.
  bool get canUseFace => canClock && faceEnabled != false && faceEnrolled;

  /// Whether the day is already complete — nothing left to clock.
  bool get dayComplete => canClock && nextPresence == null;

  static AttendanceContext fromJson(Map<String, dynamic> body) {
    return AttendanceContext(
      attendanceEnabled: asBool(body['attendance_enabled']),
      // `asBool` answers null for an absent key, which is the tristate this
      // field needs — no `?? false` here, ever.
      qrEnabled: asBool(body['qr_enabled']),
      faceEnabled: asBool(body['face_enabled']),
      faceEnrolled: asBool(body['face_enrolled']) ?? false,
      canIssueQr: asBool(body['can_issue_qr']) ?? false,
      nextPresence: PresenceDirection.parse(body['next_presence']),
      geofence: AttendanceGeofence.fromJson(body['location']),
      shift: AttendanceShift.fromJson(body['schedule']),
      serverTime: asDate(body['server_time']),
    );
  }
}
