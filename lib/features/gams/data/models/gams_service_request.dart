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
    this.serverStatusLabel,
    this.submittedAt,
    this.triagedAt,
    this.closedAt,
    this.cancelledAt,
    this.resolutionNote,
    this.answers = const {},
    this.canCancel = false,
  });

  factory GamsServiceRequest.fromJson(Map<String, dynamic> json) {
    return GamsServiceRequest(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      subject: asString(json['subject']) ?? '',
      description: asString(json['description']),
      priority: asString(json['priority']) ?? 'medium',
      status: asString(json['status']) ?? 'draft',
      serviceDefinition: _named(json['service_definition'], 'title'),
      facility: _named(json['facility'], 'name'),
      createdAt: asString(json['created_at']),
      resolvedAt: asString(json['resolved_at']),
      serverStatusLabel: asString(json['status_label']),
      submittedAt: asString(json['submitted_at']),
      triagedAt: asString(json['triaged_at']),
      closedAt: asString(json['closed_at']),
      cancelledAt: asString(json['cancelled_at']),
      resolutionNote: asString(json['resolution_note']),
      answers: asObject(asObject(json['field_data'])['fields']),
      canCancel: json['can_cancel'] == true,
    );
  }

  /// The detail endpoint names the service and the building as objects; the
  /// list names them as text. Both are read (FUNC-D05).
  static String? _named(Object? value, String key) =>
      value is Map ? asString(value[key]) : asString(value);

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

  /// The status in the panel's words, from the server (UX-D06).
  final String? serverStatusLabel;

  // Detail only (FUNC-D05).
  final String? submittedAt;
  final String? triagedAt;
  final String? closedAt;
  final String? cancelledAt;
  final String? resolutionNote;

  /// What the requester answered for the service's own fields, by key.
  final Map<String, dynamic> answers;

  /// Whether the server lets the requester withdraw it now (D-06).
  final bool canCancel;

  // `cancelled` is finished too (backend ServiceRequestStatus) — UAT review H4.
  bool get isClosed =>
      status == 'closed' || status == 'resolved' || status == 'cancelled';
  bool get isDraft => status == 'draft';

  String get statusLabel => serverStatusLabel ?? _fallbackStatusLabel;

  String get _fallbackStatusLabel => switch (status.toLowerCase()) {
    'draft' => 'Draft',
    'submitted' => 'Terkirim',
    // The server sends `triaged` (ServiceRequestStatus::Triaged); `triage`
    // stays for anything cached before that was matched (FUNC-A08).
    'triaged' || 'triage' => 'Dalam Peninjauan',
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
    this.requiresFacility = false,
    this.requiresDescription = false,
    this.fields = const [],
  });

  factory GamsServiceDefinition.fromJson(Map<String, dynamic> json) {
    return GamsServiceDefinition(
      id: asInt(json['id']) ?? 0,
      title: asString(json['title']) ?? '',
      code: asString(json['code']) ?? '',
      category: asString(json['category']),
      description: asString(json['description']),
      requiresFacility: json['requires_facility'] == true,
      requiresDescription: json['requires_description'] == true,
      fields: [
        for (final raw in asList(json['fields']))
          if (GamsRequestField.tryFromJson(asObject(raw)) case final field?)
            field,
      ],
    );
  }

  final int id;
  final String title;
  final String code;
  final String? category;
  final String? description;

  /// The service's own rules (FUNC-A01): the building and the description
  /// are required only when the service says so.
  final bool requiresFacility;
  final bool requiresDescription;

  /// The other fields this service asks for, in the server's order.
  final List<GamsRequestField> fields;

  /// Whether this app can draw every required field. A service with one it
  /// cannot is never offered: it would be refused after sending.
  bool get isRequestable =>
      fields.every((f) => !f.required || f.type != GamsFieldType.unknown);
}

/// The input types a GA service may declare for a request field.
enum GamsFieldType {
  text,
  textarea,
  number,
  boolean,
  date,
  datetime,
  select,
  multiSelect,
  unknown;

  static GamsFieldType parse(String? raw) => switch (raw) {
    'text' => text,
    'textarea' => textarea,
    'number' => number,
    'boolean' => boolean,
    'date' => date,
    'datetime' => datetime,
    'select' => select,
    'multi_select' => multiSelect,
    _ => unknown,
  };
}

/// One field a GA service asks the requester to fill (FUNC-A01).
class GamsRequestField {
  const GamsRequestField({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    this.options = const [],
  });

  static GamsRequestField? tryFromJson(Map<String, dynamic> json) {
    final key = asString(json['key']);
    if (key == null || key.isEmpty) return null;

    return GamsRequestField(
      key: key,
      label: asString(json['label']) ?? key,
      type: GamsFieldType.parse(asString(json['type'])),
      required: json['required'] == true,
      options: [
        for (final option in asList(json['options']))
          if (asString(option) case final value?) value,
      ],
    );
  }

  final String key;
  final String label;
  final GamsFieldType type;
  final bool required;
  final List<String> options;
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
