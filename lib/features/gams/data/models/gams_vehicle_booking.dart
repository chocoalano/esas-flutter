import '../../../../core/utils/json_parsers.dart';

class GamsVehicle {
  const GamsVehicle({
    required this.id,
    required this.number,
    required this.name,
    this.tag,
    this.category,
  });

  factory GamsVehicle.fromJson(Map<String, dynamic> json) {
    return GamsVehicle(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      name: asString(json['name']) ?? 'Kendaraan Operasional',
      tag: asString(json['tag']),
      category: asString(json['category']),
    );
  }

  final int id;
  final String number;
  final String name;
  final String? tag;
  final String? category;
}

class GamsVehicleBooking {
  const GamsVehicleBooking({
    required this.id,
    required this.number,
    required this.vehicleId,
    this.vehicleName,
    this.vehiclePlate,
    required this.purpose,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.canCancel = false,
    this.createdAt,
  });

  factory GamsVehicleBooking.fromJson(Map<String, dynamic> json) {
    return GamsVehicleBooking(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      vehicleId: asInt(json['vehicle_id']) ?? 0,
      vehicleName: asString(json['vehicle_name']),
      vehiclePlate: asString(json['vehicle_plate']),
      purpose: asString(json['purpose']) ?? '',
      startsAt: asString(json['starts_at']) ?? '',
      endsAt: asString(json['ends_at']) ?? '',
      status: asString(json['status']) ?? 'booking',
      canCancel: json['can_cancel'] == true,
      createdAt: asString(json['created_at']),
    );
  }

  /// Whether the server lets the requester withdraw it now (D-06).
  final bool canCancel;

  final int id;
  final String number;
  final int vehicleId;
  final String? vehicleName;
  final String? vehiclePlate;
  final String purpose;
  final String startsAt;
  final String endsAt;
  final String status;
  final String? createdAt;

  bool get isBooking => status.toLowerCase() == 'booking';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
}
