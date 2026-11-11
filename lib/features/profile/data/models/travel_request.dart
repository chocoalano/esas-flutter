import '../../../../core/utils/json_parsers.dart';

class TravelRequest {
  const TravelRequest({
    required this.id,
    required this.reference,
    required this.destination,
    required this.purpose,
    required this.departsOn,
    required this.returnsOn,
    this.days = 1,
    this.allowanceAmount = 0.0,
    required this.status,
    this.createdAt,
    this.note,
  });

  factory TravelRequest.fromJson(Map<String, dynamic> json) {
    return TravelRequest(
      id: asInt(json['id']) ?? 0,
      reference: asString(json['reference']) ?? '',
      destination: asString(json['destination']) ?? '',
      purpose: asString(json['purpose']) ?? '',
      departsOn: asString(json['departs_on']) ?? '',
      returnsOn: asString(json['returns_on']) ?? '',
      days: asInt(json['days']) ?? 1,
      allowanceAmount: asDouble(json['allowance_amount']) ?? 0.0,
      status: asString(json['status']) ?? 'draft',
      createdAt: json['created_at'] as String?,
      note: json['note'] as String?,
    );
  }

  final int id;
  final String reference;
  final String destination;
  final String purpose;
  final String departsOn;
  final String returnsOn;
  final int days;
  final double allowanceAmount;
  final String status;
  final String? createdAt;
  final String? note;

  bool get isApproved => status == 'approved';
  bool get isSubmitted => status == 'submitted';
  bool get isRejected => status == 'rejected';
  bool get isCompleted => status == 'completed';

  String get statusLabel {
    switch (status) {
      case 'submitted':
        return 'Menunggu Persetujuan';
      case 'approved':
        return 'Disetujui';
      case 'completed':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      case 'draft':
      default:
        return 'Draf';
    }
  }
}
