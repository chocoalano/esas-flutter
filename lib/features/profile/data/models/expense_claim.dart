import '../../../../core/utils/json_parsers.dart';

class ExpenseClaim {
  const ExpenseClaim({
    required this.id,
    required this.reference,
    required this.title,
    required this.total,
    required this.status,
    this.itemsCount = 0,
    this.submittedAt,
    this.settledAt,
    this.createdAt,
    this.note,
  });

  factory ExpenseClaim.fromJson(Map<String, dynamic> json) {
    return ExpenseClaim(
      id: asInt(json['id']) ?? 0,
      reference: asString(json['reference']) ?? '',
      title: asString(json['title']) ?? '',
      total: asDouble(json['total']) ?? 0.0,
      status: asString(json['status']) ?? 'draft',
      itemsCount: asInt(json['items_count']) ?? 0,
      submittedAt: json['submitted_at'] as String?,
      settledAt: json['settled_at'] as String?,
      createdAt: json['created_at'] as String?,
      note: json['note'] as String?,
    );
  }

  final int id;
  final String reference;
  final String title;
  final double total;
  final String status;
  final int itemsCount;
  final String? submittedAt;
  final String? settledAt;
  final String? createdAt;
  final String? note;

  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';
  bool get isApproved => status == 'approved';
  bool get isSettled => status == 'settled';
  bool get isRejected => status == 'rejected';

  String get statusLabel {
    switch (status) {
      case 'submitted':
        return 'Diajukan';
      case 'approved':
        return 'Disetujui';
      case 'settled':
        return 'Dicairkan';
      case 'rejected':
        return 'Ditolak';
      case 'draft':
      default:
        return 'Draf';
    }
  }
}
