import 'dart:convert';

class LeaveType {
  final int id;
  final String type;
  final bool isPayed;
  final bool approveLine;
  final bool approveManager;
  final bool approveHr;
  final bool withFile;
  final bool showMobile;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  LeaveType({
    required this.id,
    required this.type,
    required this.isPayed,
    required this.approveLine,
    required this.approveManager,
    required this.approveHr,
    required this.withFile,
    required this.showMobile,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory LeaveType.fromJson(Map<String, dynamic> json) {
    return LeaveType(
      id: json['id'] as int,
      type: json['type'] as String,
      isPayed: json['is_payed'] as bool,
      approveLine: json['approve_line'] as bool,
      approveManager: json['approve_manager'] as bool,
      approveHr: json['approve_hr'] as bool,
      withFile: json['with_file'] as bool,
      showMobile: json['show_mobile'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'is_payed': isPayed,
      'approve_line': approveLine,
      'approve_manager': approveManager,
      'approve_hr': approveHr,
      'with_file': withFile,
      'show_mobile': showMobile,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  /// Parse a list of LeaveType from JSON string or list
  static List<LeaveType> listFromJson(String jsonString) {
    final data = json.decode(jsonString) as List;
    return data
        .map((e) => LeaveType.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
