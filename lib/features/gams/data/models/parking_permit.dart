import '../../../../core/utils/json_parsers.dart';

class ParkingPermit {
  const ParkingPermit({
    required this.id,
    required this.number,
    required this.areaName,
    required this.licensePlate,
    required this.status,
    required this.statusLabel,
    this.slotNumber,
    this.validFrom,
    this.validUntil,
    this.createdAt,
  });

  factory ParkingPermit.fromJson(Map<String, dynamic> json) {
    return ParkingPermit(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      areaName: asString(json['area_name']) ?? 'Area Parkir',
      licensePlate: asString(json['license_plate']) ?? '',
      status: asString(json['status']) ?? 'requested',
      statusLabel: asString(json['status_label']) ?? 'Diajukan',
      slotNumber: asString(json['slot_number']),
      validFrom: asString(json['valid_from']),
      validUntil: asString(json['valid_until']),
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final String number;
  final String areaName;
  final String licensePlate;
  final String status;
  final String statusLabel;
  final String? slotNumber;
  final String? validFrom;
  final String? validUntil;
  final String? createdAt;
}

