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
    id: json["id"],
    userId: json["user_id"],
    phone: json["phone"],
    placebirth: json["placebirth"],
    datebirth: json["datebirth"] == null
        ? null
        : DateTime.parse(json["datebirth"]),
    gender: json["gender"],
    blood: json["blood"],
    maritalStatus: json["marital_status"],
    religion: json["religion"],
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
