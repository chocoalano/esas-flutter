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
    this.triagedAt,
    this.assignedAt,
    this.startedAt,
    this.waitingAt,
    this.closedAt,
    this.isAssigned = false,
    this.assigneeName,
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
      triagedAt: asString(json['triaged_at']),
      assignedAt: asString(json['assigned_at']),
      startedAt: asString(json['started_at']),
      waitingAt: asString(json['waiting_at']),
      closedAt: asString(json['closed_at']),
      isAssigned: json['is_assigned'] == true,
      assigneeName: asString(json['assignee_name']),
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

  // Detail only (FUNC-D04): when each step happened. Who handled it is not
  // sent; the technician's notes stay internal.
  final String? triagedAt;
  final String? assignedAt;
  final String? startedAt;
  final String? waitingAt;
  final String? closedAt;
  final bool isAssigned;

  /// The officially assigned technician's name (D-05, ADR-F), and nothing
  /// else about them. Null when unassigned or not available.
  final String? assigneeName;

  // `cancelled` is finished too (backend ItmsTicketStatus) — UAT review H4.
  bool get isClosed =>
      status == 'closed' || status == 'resolved' || status == 'cancelled';
}
