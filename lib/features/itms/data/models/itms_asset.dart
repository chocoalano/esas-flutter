import '../../../../core/utils/json_parsers.dart';

class ItmsAsset {
  const ItmsAsset({
    required this.id,
    required this.assetId,
    this.assetTag,
    this.assetName,
    this.serialNumber,
    this.assetClass,
    required this.custodyStatus,
    this.deployedAt,
    this.acknowledgedAt,
    this.returnedAt,
    this.movementReference,
  });

  factory ItmsAsset.fromJson(Map<String, dynamic> json) {
    return ItmsAsset(
      id: asInt(json['id']) ?? 0,
      assetId: asInt(json['asset_id']) ?? 0,
      assetTag: asString(json['asset_tag']),
      assetName: asString(json['asset_name']),
      serialNumber: asString(json['serial_number']),
      assetClass: asString(json['asset_class']),
      custodyStatus: asString(json['custody_status']) ?? 'assigned',
      deployedAt: asString(json['deployed_at']),
      acknowledgedAt: asString(json['acknowledged_at']),
      returnedAt: asString(json['returned_at']),
      movementReference: asString(json['movement_reference']),
    );
  }

  final int id;
  final int assetId;
  final String? assetTag;
  final String? assetName;
  final String? serialNumber;
  final String? assetClass;
  final String custodyStatus;
  final String? deployedAt;
  final String? acknowledgedAt;
  final String? returnedAt;
  final String? movementReference;

  bool get isAcknowledged =>
      acknowledgedAt != null || custodyStatus == 'in_custody';
  bool get needsAcknowledgement =>
      !isAcknowledged && custodyStatus != 'returned';
}
