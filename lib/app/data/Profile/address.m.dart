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
    id: json["id"],
    userId: json["user_id"],
    identityType: json["identity_type"],
    identityNumbers: json["identity_numbers"],
    province: json["province"],
    city: json["city"],
    citizenAddress: json["citizen_address"],
    residentialAddress: json["residential_address"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
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
