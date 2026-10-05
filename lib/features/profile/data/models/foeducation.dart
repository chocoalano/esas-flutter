import '../../../../core/utils/json_parsers.dart';

class FormalEducation {
  final int id;
  final int userId;
  final String institution;
  final String majors;
  final double score;
  final DateTime? start;
  final DateTime? finish;
  final String status;
  final bool certification;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FormalEducation({
    required this.id,
    required this.userId,
    required this.institution,
    required this.majors,
    required this.score,
    this.start,
    this.finish,
    required this.status,
    required this.certification,
    this.createdAt,
    this.updatedAt,
  });

  factory FormalEducation.fromJson(Map<String, dynamic> json) {
    // Every read is null-safe. These were `json['id'] as int` and
    // `(json['score'] as num).toDouble()`, which throw the moment a field is
    // absent or shifts type — and `score` is a string column, `start` an
    // integer year, so both of those were a crash waiting for the first
    // employee who had filled the tab in (MED-04).
    return FormalEducation(
      id: asInt(json['id']) ?? 0,
      userId: asInt(json['user_id']) ?? 0,
      institution: asString(json['institution']) ?? '',
      majors: asString(json['majors']) ?? '',
      score: asDouble(json['score']) ?? 0,
      start: asYear(json['start']),
      finish: asYear(json['finish']),
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
      'majors': majors,
      'score': score,
      'start': start?.toIso8601String(),
      'finish': finish?.toIso8601String(),
      'status': status,
      'certification': certification,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
