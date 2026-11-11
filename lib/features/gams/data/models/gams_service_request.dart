import '../../../../core/utils/json_parsers.dart';

class GamsServiceRequest {
  const GamsServiceRequest({
    required this.id,
    required this.number,
    required this.subject,
    this.description,
    required this.priority,
    required this.status,
    this.serviceDefinition,
    this.facility,
    this.createdAt,
    this.resolvedAt,
  });

  factory GamsServiceRequest.fromJson(Map<String, dynamic> json) {
    return GamsServiceRequest(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      subject: asString(json['subject']) ?? '',
      description: asString(json['description']),
      priority: asString(json['priority']) ?? 'medium',
      status: asString(json['status']) ?? 'draft',
      serviceDefinition: asString(json['service_definition']),
      facility: asString(json['facility']),
      createdAt: asString(json['created_at']),
      resolvedAt: asString(json['resolved_at']),
    );
  }

  final int id;
  final String number;
  final String subject;
  final String? description;
  final String priority;
  final String status;
  final String? serviceDefinition;
  final String? facility;
  final String? createdAt;
  final String? resolvedAt;

  bool get isClosed => status == 'closed' || status == 'resolved';
  bool get isDraft => status == 'draft';

  String get statusLabel => switch (status.toLowerCase()) {
        'draft' => 'Draft',
        'submitted' => 'Terkirim',
        'triage' => 'Dalam Peninjauan',
        'in_progress' || 'assigned' => 'Sedang Dikerjakan',
        'resolved' => 'Selesai',
        'closed' => 'Ditutup',
        'cancelled' => 'Dibatalkan',
        _ => status,
      };
}

class GamsServiceDefinition {
  const GamsServiceDefinition({
    required this.id,
    required this.title,
    required this.code,
    this.category,
    this.description,
  });

  factory GamsServiceDefinition.fromJson(Map<String, dynamic> json) {
    return GamsServiceDefinition(
      id: asInt(json['id']) ?? 0,
      title: asString(json['title']) ?? '',
      code: asString(json['code']) ?? '',
      category: asString(json['category']),
      description: asString(json['description']),
    );
  }

  final int id;
  final String title;
  final String code;
  final String? category;
  final String? description;
}

class GamsFacility {
  const GamsFacility({
    required this.id,
    required this.name,
    required this.code,
  });

  factory GamsFacility.fromJson(Map<String, dynamic> json) {
    return GamsFacility(
      id: asInt(json['id']) ?? 0,
      name: asString(json['name']) ?? '',
      code: asString(json['code']) ?? '',
    );
  }

  final int id;
  final String name;
  final String code;
}

