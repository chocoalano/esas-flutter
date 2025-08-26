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
    id: json["id"],
    userId: json["user_id"],
    fullname: json["fullname"],
    relationship: json["relationship"],
    birthdate: json["birthdate"] == null
        ? null
        : DateTime.parse(json["birthdate"]),
    maritalStatus: json["marital_status"],
    job: json["job"],
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
    "fullname": fullname,
    "relationship": relationship,
    "birthdate": birthdate?.toIso8601String(),
    "marital_status": maritalStatus,
    "job": job,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}
