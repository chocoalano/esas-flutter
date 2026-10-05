import '../../../../core/utils/json_parsers.dart';

class Family {
  int? id;
  int? userId;
  String? fullname;
  String? relationship;
  DateTime? birthdate;
  String? maritalStatus;
  String? job;
  DateTime? createdAt;
  DateTime? updatedAt;

  Family({
    this.id,
    this.userId,
    this.fullname,
    this.relationship,
    this.birthdate,
    this.maritalStatus,
    this.job,
    this.createdAt,
    this.updatedAt,
  });

  factory Family.fromJson(Map<String, dynamic> json) => Family(
    id: asInt(json["id"]),
    userId: asInt(json["user_id"]),
    fullname: asString(json["fullname"]),
    relationship: asString(json["relationship"]),
    birthdate: asDate(json["birthdate"]),
    maritalStatus: asString(json["marital_status"]),
    job: asString(json["job"]),
    createdAt: asDate(json["created_at"]),
    updatedAt: asDate(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "fullname": fullname,
    "relationship": relationship,
    "birthdate": birthdate?.toIso8601String(),
    "marital_status": maritalStatus,
    "job": job,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}
