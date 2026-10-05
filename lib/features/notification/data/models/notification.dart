import '../../../../core/utils/json_parsers.dart';

/// One notification row.
///
/// Every field was a hard cast — `json['id'] as String`, `json['notifiable_id']
/// as int`, `DateTime.parse(json['created_at'] as String)` — and the nested
/// `data` and `notifiable` objects were cast to `Map<String, dynamic>` before
/// being parsed. Any null or shifted type threw inside `fromJson`, and the
/// caller reported it as a generic failure with the field name already lost
/// (MED-04).
///
/// Fields that the UI genuinely cannot render without stay non-null, but they
/// now come from the null-safe accessors with visibly-empty defaults rather than
/// from casts that throw (R-10).
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.notifiableType,
    required this.notifiableId,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    required this.notifiable,
    this.readAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: asString(json['id']) ?? '',
      type: asString(json['type']) ?? '',
      notifiableType: asString(json['notifiable_type']) ?? '',
      notifiableId: asInt(json['notifiable_id']) ?? 0,
      data: NotificationData.fromJson(asObject(json['data'])),
      readAt: asDate(json['read_at']),
      createdAt: asDate(json['created_at']) ?? DateTime.now(),
      updatedAt: asDate(json['updated_at']) ?? DateTime.now(),
      notifiable: NotifiableUser.fromJson(asObject(json['notifiable'])),
    );
  }

  final String id;
  final String type;
  final String notifiableType;
  final int notifiableId;
  final NotificationData data;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NotifiableUser notifiable;

  bool get isRead => readAt != null;

  /// Used for the optimistic read-marking, which previously rebuilt the whole
  /// object field by field at the call site.
  NotificationModel copyWith({DateTime? readAt, DateTime? updatedAt}) {
    return NotificationModel(
      id: id,
      type: type,
      notifiableType: notifiableType,
      notifiableId: notifiableId,
      data: data,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notifiable: notifiable,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'notifiable_type': notifiableType,
    'notifiable_id': notifiableId,
    'data': data.toJson(),
    'read_at': readAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'notifiable': notifiable.toJson(),
  };
}

class NotificationData {
  const NotificationData({
    required this.title,
    required this.message,
    required this.url,
    this.payload = const {},
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      title: asString(json['title']) ?? '',
      message: asString(json['message']) ?? asString(json['body']) ?? '',
      url: asString(json['url']) ?? '',
      payload: Map<String, dynamic>.from(json),
    );
  }

  final String title;
  final String message;
  final String url;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    ...payload,
    'title': title,
    'message': message,
    'url': url,
  };
}

class NotifiableUser {
  const NotifiableUser({
    required this.id,
    required this.name,
    required this.nip,
    this.companyId,
    this.email,
    this.avatar,
    this.status,
    this.deviceId,
    this.emailVerifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory NotifiableUser.fromJson(Map<String, dynamic> json) {
    return NotifiableUser(
      id: asInt(json['id']) ?? 0,
      companyId: asInt(json['company_id']),
      name: asString(json['name']) ?? '',
      nip: asString(json['nip']) ?? '',
      email: asString(json['email']),
      // `avatar` was `json['avatar'] as String` — and avatar is treated as
      // optional everywhere else in the app, so this was the most likely cast
      // in the file to throw in production.
      avatar: asString(json['avatar']),
      status: asString(json['status']),
      deviceId: asString(json['device_id']),
      emailVerifiedAt: asDate(json['email_verified_at']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }

  final int id;
  final int? companyId;
  final String name;
  final String nip;
  final String? email;
  final String? avatar;
  final String? status;
  final String? deviceId;
  final DateTime? emailVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'name': name,
    'nip': nip,
    'email': email,
    'avatar': avatar,
    'status': status,
    'device_id': deviceId,
    'email_verified_at': emailVerifiedAt?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
