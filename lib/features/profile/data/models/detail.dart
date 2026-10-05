import '../../../../core/utils/json_parsers.dart';

class Details {
  int? id;
  int? userId;
  String? phone;
  String? placebirth;
  DateTime? datebirth;
  String? gender;
  String? blood;
  String? maritalStatus;
  String? religion;
  dynamic createdAt;
  dynamic updatedAt;

  Details({
    this.id,
    this.userId,
    this.phone,
    this.placebirth,
    this.datebirth,
    this.gender,
    this.blood,
    this.maritalStatus,
    this.religion,
    this.createdAt,
    this.updatedAt,
  });

  factory Details.fromJson(Map<String, dynamic> json) => Details(
    id: asInt(json["id"]),
    userId: asInt(json["user_id"]),
    phone: asString(json["phone"]),
    placebirth: asString(json["placebirth"]),
    datebirth: asDate(json["datebirth"]),
    gender: asString(json["gender"]),
    blood: asString(json["blood"]),
    maritalStatus: asString(json["marital_status"]),
    religion: asString(json["religion"]),
    createdAt: json["created_at"],
    updatedAt: json["updated_at"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "phone": phone,
    "placebirth": placebirth,
    "datebirth": datebirth?.toIso8601String(),
    "gender": gender,
    "blood": blood,
    "marital_status": maritalStatus,
    "religion": religion,
    "created_at": createdAt,
    "updated_at": updatedAt,
  };
}
