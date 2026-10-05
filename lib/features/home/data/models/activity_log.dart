import 'package:esas/core/utils/json_parsers.dart';
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
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
    this.createdAt,
    this.updatedAt,
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
      id: asInt(json['id']) ?? 0,
      userId: asInt(json['user_id']) ?? 0,
      method: asString(json['method']) ?? '',
      url: asString(json['url']) ?? '',
      action: asString(json['action']) ?? '',
      modelType: asString(json['model_type']) ?? '',
      modelId: asInt(json['model_id']) ?? 0,
      payload: parsedPayload,
      ipAddress: asString(json['ip_address']) ?? '',
      userAgent: asString(json['user_agent']) ?? '',
      // `DateTime.tryParse(json['x'] ?? '')` throws rather than returns null
      // when the value is a number, and its `?? DateTime.now()` fallback put
      // *this moment* on a row the server never dated — which on a security
      // screen reads as activity that just happened.
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
      deletedAt: asDate(json['deleted_at']),
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
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
