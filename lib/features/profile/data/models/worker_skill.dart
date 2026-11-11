import '../../../../core/utils/json_parsers.dart';

class WorkerSkill {
  const WorkerSkill({
    required this.id,
    required this.skillName,
    this.skillCode,
    this.category = 'Umum',
    required this.levelName,
    required this.levelScore,
    required this.status,
    this.source,
    this.effectiveDate,
    this.certificateNumber,
  });

  factory WorkerSkill.fromJson(Map<String, dynamic> json) {
    return WorkerSkill(
      id: asInt(json['id']) ?? 0,
      skillName: asString(json['skill_name']) ?? 'Keahlian',
      skillCode: asString(json['skill_code']),
      category: asString(json['category']) ?? 'Umum',
      levelName: asString(json['level_name']) ?? 'Standar',
      levelScore: asInt(json['level_score']) ?? 1,
      status: asString(json['status']) ?? 'verified',
      source: asString(json['source']),
      effectiveDate: asString(json['effective_date']),
      certificateNumber: asString(json['certificate_number']),
    );
  }

  final int id;
  final String skillName;
  final String? skillCode;
  final String category;
  final String levelName;
  final int levelScore;
  final String status;
  final String? source;
  final String? effectiveDate;
  final String? certificateNumber;
}
