import '../../../../core/utils/json_parsers.dart';

class ItmsTicket {
  const ItmsTicket({
    required this.id,
    required this.serviceId,
    this.serviceName,
    this.serviceCode,
    this.serviceCategory,
    required this.subject,
    this.description,
    required this.status,
    required this.statusLabel,
    this.waitingReason,
    this.resolutionNotes,
    this.createdAt,
    this.resolvedAt,
  });

  factory ItmsTicket.fromJson(Map<String, dynamic> json) {
    return ItmsTicket(
      id: asInt(json['id']) ?? 0,
      serviceId: asInt(json['service_id']) ?? 0,
      serviceName: asString(json['service_name']),
      serviceCode: asString(json['service_code']),
      serviceCategory: asString(json['service_category']),
      subject: asString(json['subject']) ?? '',
      description: asString(json['description']),
      status: asString(json['status']) ?? 'new',
      statusLabel: asString(json['status_label']) ?? 'Baru',
      waitingReason: asString(json['waiting_reason']),
      resolutionNotes: asString(json['resolution_notes']),
      createdAt: asString(json['created_at']),
      resolvedAt: asString(json['resolved_at']),
    );
  }

  final int id;
  final int serviceId;
  final String? serviceName;
  final String? serviceCode;
  final String? serviceCategory;
  final String subject;
  final String? description;
  final String status;
  final String statusLabel;
  final String? waitingReason;
  final String? resolutionNotes;
  final String? createdAt;
  final String? resolvedAt;

  bool get isClosed => status == 'closed' || status == 'resolved';
}

