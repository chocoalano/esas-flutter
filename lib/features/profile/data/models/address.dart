import '../../../../core/utils/json_parsers.dart';

class Address {
  int? id;
  int? userId;
  String? identityType;
  String? identityNumbers;
  String? province;
  String? city;
  String? citizenAddress;
  String? residentialAddress;
  DateTime? createdAt;
  DateTime? updatedAt;

  Address({
    this.id,
    this.userId,
    this.identityType,
    this.identityNumbers,
    this.province,
    this.city,
    this.citizenAddress,
    this.residentialAddress,
    this.createdAt,
    this.updatedAt,
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: asInt(json["id"]),
    userId: asInt(json["user_id"]),
    identityType: asString(json["identity_type"]),
    identityNumbers: asString(json["identity_numbers"]),
    province: asString(json["province"]),
    city: asString(json["city"]),
    citizenAddress: asString(json["citizen_address"]),
    residentialAddress: asString(json["residential_address"]),
    createdAt: asDate(json["created_at"]),
    updatedAt: asDate(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "identity_type": identityType,
    "identity_numbers": identityNumbers,
    "province": province,
    "city": city,
    "citizen_address": citizenAddress,
    "residential_address": residentialAddress,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}
