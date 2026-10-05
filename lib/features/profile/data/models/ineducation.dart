import '../../../../core/utils/json_parsers.dart';

class InformalEducationModel {
  final int id;
  final int userId;
  final String institution;
  final DateTime? start;
  final DateTime? finish;
  final String type;
  final int duration;
  final String status;
  final bool certification;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  InformalEducationModel({
    required this.id,
    required this.userId,
    required this.institution,
    this.start,
    this.finish,
    required this.type,
    required this.duration,
    required this.status,
    required this.certification,
    this.createdAt,
    this.updatedAt,
  });

  factory InformalEducationModel.fromJson(Map<String, dynamic> json) {
    return InformalEducationModel(
      id: asInt(json['id']) ?? 0,
      userId: asInt(json['user_id']) ?? 0,
      institution: asString(json['institution']) ?? '',
      start: asYear(json['start']),
      finish: asYear(json['finish']),
      type: asString(json['type']) ?? '',
      duration: asInt(json['duration']) ?? 0,
      status: asString(json['status']) ?? '',
      certification: asBool(json['certification']) ?? false,
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'institution': institution,
      'start': start?.toIso8601String(),
      'finish': finish?.toIso8601String(),
      'type': type,
      'duration': duration,
      'status': status,
      'certification': certification,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
