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
      id: json['id'] as int,
      userId: json['user_id'] as int,
      institution: json['institution'] as String,
      start: json['start'] != null ? DateTime.tryParse(json['start']) : null,
      finish: json['finish'] != null ? DateTime.tryParse(json['finish']) : null,
      type: json['type'] as String,
      duration: json['duration'] as int,
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
