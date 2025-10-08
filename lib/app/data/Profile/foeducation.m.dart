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
    return FormalEducation(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      institution: json['institution'] as String,
      majors: json['majors'] as String,
      score: (json['score'] as num).toDouble(),
      start: json['start'] != null ? DateTime.tryParse(json['start']) : null,
      finish: json['finish'] != null ? DateTime.tryParse(json['finish']) : null,
      status: json['status'] as String,
      certification:
          json['certification'] == true || json['certification'] == 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
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
