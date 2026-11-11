import '../../../../core/utils/json_parsers.dart';

class GamsSpace {
  const GamsSpace({
    required this.id,
    required this.name,
    required this.code,
    required this.kind,
    this.capacity,
    this.zone,
  });

  factory GamsSpace.fromJson(Map<String, dynamic> json) {
    return GamsSpace(
      id: asInt(json['id']) ?? 0,
      name: asString(json['name']) ?? '',
      code: asString(json['code']) ?? '',
      kind: asString(json['kind']) ?? 'Meeting Room',
      capacity: asInt(json['capacity']),
      zone: asString(json['zone']),
    );
  }

  final int id;
  final String name;
  final String code;
  final String kind;
  final int? capacity;
  final String? zone;
}

class GamsSpaceReservation {
  const GamsSpaceReservation({
    required this.id,
    required this.spaceId,
    this.spaceName,
    this.spaceKind,
    this.zoneName,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.createdAt,
  });

  factory GamsSpaceReservation.fromJson(Map<String, dynamic> json) {
    return GamsSpaceReservation(
      id: asInt(json['id']) ?? 0,
      spaceId: asInt(json['space_id']) ?? 0,
      spaceName: asString(json['space_name']),
      spaceKind: asString(json['space_kind']) ?? 'Ruang Rapat',
      zoneName: asString(json['zone_name']),
      startAt: asString(json['start_at']) ?? '',
      endAt: asString(json['end_at']) ?? '',
      status: asString(json['status']) ?? 'confirmed',
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final int spaceId;
  final String? spaceName;
  final String? spaceKind;
  final String? zoneName;
  final String startAt;
  final String endAt;
  final String status;
  final String? createdAt;

  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isConfirmed => status.toLowerCase() == 'confirmed';
}

