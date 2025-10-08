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
    id: json["id"],
    companyId: json["company_id"],
    name: json["name"],
    nip: json["nip"],
    email: json["email"],
    emailVerifiedAt: json["email_verified_at"] == null
        ? null
        : DateTime.parse(json["email_verified_at"]),
    avatar: json["avatar"],
    status: json["status"], // Added null check
    deviceId: json["device_id"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
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
