import '../../../../core/utils/json_parsers.dart';

class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.deviceId,
    required this.isRegisteredDevice,
    required this.isCurrent,
    required this.abilities,
    this.lastUsedAt,
    this.createdAt,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: asInt(json['id']) ?? 0,
      deviceId: asString(json['device_id']) ?? '',
      isRegisteredDevice: json['is_registered_device'] == true,
      isCurrent: json['is_current'] == true,
      abilities: (json['abilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      lastUsedAt: asString(json['last_used_at']),
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final String deviceId;
  final bool isRegisteredDevice;
  final bool isCurrent;
  final List<String> abilities;
  final String? lastUsedAt;
  final String? createdAt;
}

