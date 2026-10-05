import '../../../../core/utils/json_parsers.dart';
import '../../presentation/attendance_labels.dart';
import 'attendance_user.dart';

class Attendance {
  int? id;
  int? userId;
  int? userTimeworkScheduleId;
  String? timeIn;
  String? timeOut;
  String? typeIn; // Corrected to TypeAttendance
  String? typeOut; // Corrected to TypeAttendance
  String? latIn;
  String? latOut;
  String? longIn;
  String? longOut;
  String? imageIn;
  String? imageOut;
  String? statusIn;
  String? statusOut;
  String? datePresence;
  int? createdBy;
  int? updatedBy;
  DateTime? createdAt;
  DateTime? updatedAt;
  User? user;

  /// The rostered shift's name, when the day had one — `Shift Pagi`.
  ///
  /// Sent by `AttendanceHistoryController::row()` as `shift`, and dropped by
  /// this model until now: it read a `schedule` key the server has never sent,
  /// so every screen behaved as though no roster existed. Its absence is why
  /// "Tepat waktu" had nothing to be measured against — see [hasSchedule].
  String? shift;

  /// `HH:MM:SS` the shift was due to start and end.
  String? shiftIn;
  String? shiftOut;

  /// What the work calendar calls the day: `working`, `rest` or `holiday`.
  ///
  /// Also sent all along and also discarded. It is the only thing that can tell
  /// a rest day apart from a day somebody failed to clock.
  String? dayType;

  Attendance({
    this.id,
    this.userId,
    this.userTimeworkScheduleId,
    this.timeIn,
    this.timeOut,
    this.typeIn,
    this.typeOut,
    this.latIn,
    this.latOut,
    this.longIn,
    this.longOut,
    this.imageIn,
    this.imageOut,
    this.statusIn,
    this.statusOut,
    this.datePresence,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.shift,
    this.shiftIn,
    this.shiftOut,
    this.dayType,
  });

  /// Parse a row from the attendance history.
  ///
  /// Every field goes through the shared null-safe accessors. The version this
  /// replaces read the map untyped and then called
  /// `DateTime.parse(json["created_at"])` on the result — which throws twice
  /// over on a null, and whose failure `HomeController` converted into
  /// `FormatException('Response format tidak sesuai')`, erasing the field name
  /// and leaving a production parse failure undiagnosable (MED-04).
  ///
  /// Defaults are deliberately *visibly* empty rather than plausible: a wrong
  /// time that looks real is worse than a blank one on an attendance record
  /// (R-10).
  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
    id: asInt(json['id']),
    userId: asInt(json['user_id']),
    userTimeworkScheduleId: asInt(json['user_timework_schedule_id']),
    timeIn: asString(json['time_in']),
    timeOut: asString(json['time_out']),
    typeIn: asString(json['type_in']),
    typeOut: asString(json['type_out']),
    latIn: asString(json['lat_in']),
    latOut: asString(json['lat_out']),
    longIn: asString(json['long_in']),
    longOut: asString(json['long_out']),
    imageIn: asString(json['image_in']),
    imageOut: asString(json['image_out']),
    statusIn: asString(json['status_in']),
    statusOut: asString(json['status_out']),
    datePresence: asString(json['date_presence']),
    createdBy: asInt(json['created_by']),
    updatedBy: asInt(json['updated_by']),
    createdAt: asDate(json['created_at']),
    updatedAt: asDate(json['updated_at']),
    user: json['user'] is Map ? User.fromJson(asObject(json['user'])) : null,
    shift: asString(json['shift']),
    shiftIn: asString(json['shift_in']),
    shiftOut: asString(json['shift_out']),
    dayType: asString(json['day_type']),
  );

  /// Whether the roster expected anything of this day.
  ///
  /// The one fact that decides whether a status may be read as punctuality.
  /// `RecordAttendance::status()` returns `Normal` unconditionally when the day
  /// had no shift — so `Normal` means "on time" only when this is true, and
  /// "there was nothing to be late for" when it is false.
  bool get hasSchedule => (shiftIn ?? '').isNotEmpty;

  /// Whether the shift runs past midnight.
  bool get crossesMidnight {
    final start = attendanceMinuteOfDay(shiftIn);
    final end = attendanceMinuteOfDay(shiftOut);

    return start != null && end != null && end <= start;
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "user_timework_schedule_id": userTimeworkScheduleId,
    "time_in": timeIn,
    "time_out": timeOut,
    "type_in": typeIn, // Added null check
    "type_out": typeOut, // Added null check
    "lat_in": latIn,
    "lat_out": latOut,
    "long_in": longIn,
    "long_out": longOut,
    "image_in": imageIn,
    "image_out": imageOut,
    "status_in": statusIn, // Added null check
    "status_out": statusOut, // Added null check
    "date_presence": datePresence,
    "created_by": createdBy,
    "updated_by": updatedBy,
    "shift": shift,
    "shift_in": shiftIn,
    "shift_out": shiftOut,
    "day_type": dayType,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "user": user?.toJson(),
  };
}
