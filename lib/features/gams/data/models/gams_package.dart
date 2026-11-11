import '../../../../core/utils/json_parsers.dart';

class GamsPackage {
  const GamsPackage({
    required this.id,
    required this.trackingNumber,
    required this.recipientWorkerUid,
    this.courier,
    this.sender,
    required this.status,
    required this.statusLabel,
    this.receivedAt,
    this.collectedAt,
    this.createdAt,
  });

  factory GamsPackage.fromJson(Map<String, dynamic> json) {
    return GamsPackage(
      id: asInt(json['id']) ?? 0,
      trackingNumber: asString(json['tracking_number']) ?? '',
      recipientWorkerUid: asString(json['recipient_worker_uid']) ?? '',
      courier: asString(json['courier']),
      sender: asString(json['sender']),
      status: asString(json['status']) ?? 'received',
      statusLabel: asString(json['status_label']) ?? 'Tiba di Mailroom',
      receivedAt: asString(json['received_at']),
      collectedAt: asString(json['collected_at']),
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final String trackingNumber;
  final String recipientWorkerUid;
  final String? courier;
  final String? sender;
  final String status;
  final String statusLabel;
  final String? receivedAt;
  final String? collectedAt;
  final String? createdAt;
}

