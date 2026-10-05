import '../../../../core/utils/json_parsers.dart';

class WorkExperienceModel {
  final int id;
  final int userId;
  final String companyName;
  final DateTime? start;
  final DateTime? finish;
  final String? position;
  final bool certification;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WorkExperienceModel({
    required this.id,
    required this.userId,
    required this.companyName,
    this.start,
    this.finish,
    this.position,
    required this.certification,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkExperienceModel.fromJson(Map<String, dynamic> json) {
    return WorkExperienceModel(
      id: asInt(json['id']) ?? 0,
      userId: asInt(json['user_id']) ?? 0,
      companyName: asString(json['company_name']) ?? '',
      start: asYear(json['start']),
      finish: asYear(json['finish']),
      position: asString(json['position']),
      certification: asBool(json['certification']) ?? false,
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'company_name': companyName,
      'start': start?.toIso8601String(),
      'finish': finish?.toIso8601String(),
      'position': position,
      'certification': certification,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
