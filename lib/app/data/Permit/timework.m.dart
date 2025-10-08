class Timework {
  int? id;
  int? companyId;
  int? departemenId;
  String? name;
  String? timeworkIn;
  String? out;
  DateTime? createdAt;
  DateTime? updatedAt;

  Timework({
    this.id,
    this.companyId,
    this.departemenId,
    this.name,
    this.timeworkIn,
    this.out,
    this.createdAt,
    this.updatedAt,
  });

  factory Timework.fromJson(Map<String, dynamic> json) => Timework(
    id: json["id"],
    companyId: json["company_id"],
    departemenId: json["departemen_id"],
    name: json["name"],
    timeworkIn: json["in"],
    out: json["out"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "company_id": companyId,
    "departemen_id": departemenId,
    "name": name,
    "in": timeworkIn,
    "out": out,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}
