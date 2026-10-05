import 'dart:convert';

class ActivityLog {
  final int id;
  final int userId;
  final String method;
  final String url;
  final String action;
  final String modelType;
  final int modelId;
  final Map<String, dynamic> payload;
  final String ipAddress;
  final String userAgent;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.method,
    required this.url,
    required this.action,
    required this.modelType,
    required this.modelId,
    required this.payload,
    required this.ipAddress,
    required this.userAgent,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedPayload = {};

    final rawPayload = json['payload'];

    if (rawPayload is Map<String, dynamic>) {
      parsedPayload = rawPayload;
    } else if (rawPayload is String && rawPayload.isNotEmpty) {
      try {
        parsedPayload = jsonDecode(rawPayload) as Map<String, dynamic>;
      } catch (e) {
        parsedPayload = {}; // fallback
      }
    }

    return ActivityLog(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      method: json['method'] as String? ?? '',
      url: json['url'] as String? ?? '',
      action: json['action'] as String? ?? '',
      modelType: json['model_type'] as String? ?? '',
      modelId: json['model_id'] as int? ?? 0,
      payload: parsedPayload,
      ipAddress: json['ip_address'] as String? ?? '',
      userAgent: json['user_agent'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'method': method,
      'url': url,
      'action': action,
      'model_type': modelType,
      'model_id': modelId,
      'payload': payload, // biarkan sebagai Map, bukan jsonEncode
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
