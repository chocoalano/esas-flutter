import 'user.m.dart';

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
  dynamic schedule;

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
    this.schedule,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
    id: json["id"],
    userId: json["user_id"],
    userTimeworkScheduleId: json["user_timework_schedule_id"],
    timeIn: json["time_in"],
    timeOut: json["time_out"],
    typeIn: json["type_in"], // Added null check
    typeOut: json["type_out"], // Added null check
    latIn: json["lat_in"],
    latOut: json["lat_out"],
    longIn: json["long_in"],
    longOut: json["long_out"],
    imageIn: json["image_in"],
    imageOut: json["image_out"],
    statusIn: json["status_in"], // Added null check
    statusOut: json["status_out"], // Added null check
    datePresence: json["date_presence"],
    createdBy: json["created_by"],
    updatedBy: json["updated_by"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    user: json["user"] == null ? null : User.fromJson(json["user"]),
    schedule: json["schedule"],
  );

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
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "user": user?.toJson(),
    "schedule": schedule,
  };
}
