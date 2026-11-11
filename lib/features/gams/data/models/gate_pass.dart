import '../../../../core/utils/json_parsers.dart';

class GatePass {
  const GatePass({
    required this.id,
    required this.number,
    required this.facilityId,
    required this.facilityName,
    required this.status,
    required this.statusLabel,
    required this.itemCount,
    this.carrierOrActor,
    this.createdAt,
  });

  factory GatePass.fromJson(Map<String, dynamic> json) {
    return GatePass(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      facilityId: asInt(json['facility_id']) ?? 0,
      facilityName: asString(json['facility_name']) ?? 'Fasilitas',
      status: asString(json['status']) ?? 'draft',
      statusLabel: asString(json['status_label']) ?? 'Draft',
      itemCount: asInt(json['item_count']) ?? 0,
      carrierOrActor: asString(json['carrier_or_actor']),
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final String number;
  final int facilityId;
  final String facilityName;
  final String status;
  final String statusLabel;
  final int itemCount;
  final String? carrierOrActor;
  final String? createdAt;
}

