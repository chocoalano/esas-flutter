class NotificationModel {
  final String id;
  final String type;
  final String notifiableType;
  final int notifiableId;
  final NotificationData data;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NotifiableUser notifiable;

  NotificationModel({
    required this.id,
    required this.type,
    required this.notifiableType,
    required this.notifiableId,
    required this.data,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
    required this.notifiable,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String,
      notifiableType: json['notifiable_type'] as String,
      notifiableId: json['notifiable_id'] as int,
      data: NotificationData.fromJson(json['data'] as Map<String, dynamic>),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      notifiable: NotifiableUser.fromJson(
        json['notifiable'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
}

class NotificationData {
  final String title;
  final String message;
  final String url;
  final dynamic createdBy; // Can be null, so dynamic or String?

  NotificationData({
    required this.title,
    required this.message,
    required this.url,
    this.createdBy,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      title: json['title'] as String,
      message: json['message'] as String,
      url: json['url'] as String,
      createdBy: json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'url': url,
      'created_by': createdBy,
    };
  }
}

class NotifiableUser {
  final int id;
  final int companyId;
  final String name;
  final String nip;
  final String email;
  final DateTime? emailVerifiedAt;
  final String avatar;
  final String status;
  final String deviceId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final dynamic deletedAt; // Can be null, so dynamic or DateTime?

  NotifiableUser({
    required this.id,
    required this.companyId,
    required this.name,
    required this.nip,
    required this.email,
    this.emailVerifiedAt,
    required this.avatar,
    required this.status,
    required this.deviceId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory NotifiableUser.fromJson(Map<String, dynamic> json) {
    return NotifiableUser(
      id: json['id'] as int,
      companyId: json['company_id'] as int,
      name: json['name'] as String,
      nip: json['nip'] as String,
      email: json['email'] as String,
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.parse(json['email_verified_at'] as String)
          : null,
      avatar: json['avatar'] as String,
      status: json['status'] as String,
      deviceId: json['device_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      'nip': nip,
      'email': email,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'avatar': avatar,
      'status': status,
      'device_id': deviceId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt,
    };
  }
}
