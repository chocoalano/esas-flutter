import '../../../../core/utils/json_parsers.dart';

class InventoryRequest {
  const InventoryRequest({
    required this.id,
    required this.number,
    required this.itemName,
    required this.locationName,
    required this.quantity,
    required this.unit,
    required this.status,
    required this.statusLabel,
    this.createdAt,
  });

  factory InventoryRequest.fromJson(Map<String, dynamic> json) {
    return InventoryRequest(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      itemName: asString(json['item_name']) ?? 'Barang ATK',
      locationName: asString(json['location_name']) ?? 'Gudang GA',
      quantity: asInt(json['quantity']) ?? 1,
      unit: asString(json['unit']) ?? 'pcs',
      status: asString(json['status']) ?? 'requested',
      statusLabel: asString(json['status_label']) ?? 'Diajukan',
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final String number;
  final String itemName;
  final String locationName;
  final int quantity;
  final String unit;
  final String status;
  final String statusLabel;
  final String? createdAt;
}

