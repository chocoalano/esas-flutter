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
      id: json['id'] as int,
      userId: json['user_id'] as int,
      companyName: json['company_name'] as String,
      start: json['start'] != null ? DateTime.tryParse(json['start']) : null,
      finish: json['finish'] != null ? DateTime.tryParse(json['finish']) : null,
      position: json['position'] as String?,
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
