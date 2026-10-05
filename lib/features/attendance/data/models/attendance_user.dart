import 'package:esas/core/utils/json_parsers.dart';

class User {
  int? id;
  int? companyId;
  String? name;
  String? nip;
  String? email;
  DateTime? emailVerifiedAt;
  String? avatar;
  String? status;
  String? deviceId;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;

  User({
    this.id,
    this.companyId,
    this.name,
    this.nip,
    this.email,
    this.emailVerifiedAt,
    this.avatar,
    this.status,
    this.deviceId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: asInt(json["id"]),
    companyId: asInt(json["company_id"]),
    name: asString(json["name"]),
    nip: asString(json["nip"]),
    email: asString(json["email"]),
    emailVerifiedAt: asDate(json["email_verified_at"]),
    avatar: asString(json["avatar"]),
    status: asString(json["status"]),
    deviceId: asString(json["device_id"]),
    createdAt: asDate(json["created_at"]),
    updatedAt: asDate(json["updated_at"]),
    deletedAt: json["deleted_at"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "company_id": companyId,
    "name": name,
    "nip": nip,
    "email": email,
    "email_verified_at": emailVerifiedAt?.toIso8601String(),
    "avatar": avatar,
    "status": status, // Added null check
    "device_id": deviceId,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
  };
}
