import '../../../../core/utils/json_parsers.dart';

class Departement {
  int? id;
  int? companyId;
  String? name;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;
  int? departementId;

  Departement({
    this.id,
    this.companyId,
    this.name,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.departementId,
  });

  factory Departement.fromJson(Map<String, dynamic> json) => Departement(
    id: asInt(json["id"]),
    companyId: asInt(json["company_id"]),
    name: asString(json["name"]),
    createdAt: asDate(json["created_at"]),
    updatedAt: asDate(json["updated_at"]),
    deletedAt: json["deleted_at"],
    departementId: asInt(json["departement_id"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "company_id": companyId,
    "name": name,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "departement_id": departementId,
  };
}
