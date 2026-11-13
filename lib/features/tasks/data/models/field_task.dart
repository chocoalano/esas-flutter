import '../../../../core/registry/module_registry.dart';

/// The operational domain a field task belongs to. Each one keeps its own
/// lifecycle on the server; the app only presents them together.
enum TaskDomain {
  gams(EsasModules.gams, 'GA', 'Pekerjaan GA'),
  itms(EsasModules.itms, 'IT', 'Tiket IT'),
  mtms(EsasModules.mtms, 'Maintenance', 'Perintah kerja');

  const TaskDomain(this.module, this.shortLabel, this.label);

  /// The module key the tenant's `active_modules` uses.
  final String module;
  final String shortLabel;
  final String label;

  static TaskDomain? of(String? value) {
    for (final domain in values) {
      if (domain.name == value || domain.module == value) return domain;
    }
    return null;
  }
}

/// One task assigned to the signed-in worker, as the list shows it.
class FieldTask {
  const FieldTask({
    required this.domain,
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    required this.statusLabel,
    this.location,
    this.priority,
    this.scheduledAt,
    this.dateLabel = 'Jadwal',
    this.lockVersion,
    this.allowedActions = const [],
  });

  /// The list endpoints differ in two key names: GAMS kept `subject` and
  /// `facility_name` from its first release, ITMS and MTMS send `title` and
  /// `location`.
  factory FieldTask.fromJson(TaskDomain domain, Map<String, dynamic> json) {
    return FieldTask(
      domain: domain,
      id: _int(json['id']),
      number: '${json['number'] ?? '#${json['id']}'}',
      title: '${json['title'] ?? json['subject'] ?? '-'}',
      location: _text(json['location'] ?? json['facility_name']),
      priority: _text(json['priority']),
      status: '${json['status'] ?? ''}',
      statusLabel: '${json['status_label'] ?? json['status'] ?? ''}',
      scheduledAt: _date(json['scheduled_at'] ?? json['issued_at']),
      // GAMS sends when the order was issued, not a schedule (UX-D10).
      dateLabel: json['scheduled_at'] == null && json['issued_at'] != null
          ? 'Diterbitkan'
          : 'Jadwal',
      lockVersion: json['lock_version'] is int
          ? json['lock_version'] as int
          : null,
      allowedActions: _strings(json['allowed_actions']),
    );
  }

  final TaskDomain domain;
  final int id;
  final String number;
  final String title;
  final String? location;
  final String? priority;
  final String status;
  final String statusLabel;
  final DateTime? scheduledAt;

  /// What [scheduledAt] means for this domain: a schedule, or an issue date.
  final String dateLabel;
  final int? lockVersion;

  /// What the server will let this worker do right now. The app shows no
  /// button that is not in here.
  final List<String> allowedActions;

  bool get needsAction => allowedActions.isNotEmpty;

  /// The priority in words (UX-D10), or null when the domain has none.
  String? get priorityLabel => switch (priority) {
    null => null,
    'low' => 'Rendah',
    'normal' => 'Normal',
    'high' => 'Tinggi',
    'urgent' => 'Mendesak',
    'critical' => 'Kritis',
    final other => other,
  };

  /// Reported done, but not final: someone else still has to look at it
  /// (UX-D11). Null while the work is not yet reported.
  String? get reviewHint => switch (status) {
    'completed' || 'technically_completed' => 'Menunggu verifikasi',
    'resolved' => 'Menunggu konfirmasi pemohon',
    _ => null,
  };
}

/// A dated step of the task's own history.
class TaskHistoryEntry {
  const TaskHistoryEntry({
    required this.to,
    required this.label,
    this.note,
    this.at,
  });

  factory TaskHistoryEntry.fromJson(Map<String, dynamic> json) =>
      TaskHistoryEntry(
        to: '${json['to'] ?? ''}',
        label: '${json['to_label'] ?? json['to'] ?? ''}',
        note: _text(json['note']),
        at: _date(json['at']),
      );

  final String to;
  final String label;
  final String? note;
  final DateTime? at;
}

/// A checklist line (GAMS) or a maintenance task (MTMS).
class TaskStep {
  const TaskStep({
    required this.id,
    required this.description,
    required this.isMandatory,
    required this.isDone,
  });

  factory TaskStep.fromJson(Map<String, dynamic> json) => TaskStep(
    id: _int(json['id']),
    description: '${json['description'] ?? ''}',
    isMandatory: json['is_mandatory'] == true,
    isDone: json['is_done'] == true || json['is_completed'] == true,
  );

  final int id;
  final String description;
  final bool isMandatory;
  final bool isDone;
}

/// A labor interval the worker clocked on an MTMS work order.
class LaborInterval {
  const LaborInterval({
    required this.id,
    this.startedAt,
    this.endedAt,
    this.notes,
  });

  factory LaborInterval.fromJson(Map<String, dynamic> json) => LaborInterval(
    id: _int(json['id']),
    startedAt: _date(json['started_at']),
    endedAt: _date(json['ended_at']),
    notes: _text(json['notes']),
  );

  final int id;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? notes;

  bool get isOpen => endedAt == null;
}

/// Everything the detail screen shows about one task.
class FieldTaskDetail {
  const FieldTaskDetail({
    required this.task,
    this.description,
    this.requesterName,
    this.assignedAt,
    this.assignedBy,
    this.report,
    this.verificationNote,
    this.verifiedAt,
    this.equipment,
    this.safetyClass,
    this.requestNumber,
    this.steps = const [],
    this.labor = const [],
    this.history = const [],
  });

  factory FieldTaskDetail.fromJson(
    TaskDomain domain,
    Map<String, dynamic> json,
  ) {
    final assignment = json['assignment'] is Map
        ? Map<String, dynamic>.from(json['assignment'] as Map)
        : const <String, dynamic>{};

    return FieldTaskDetail(
      task: FieldTask.fromJson(domain, json),
      description: _text(json['description']),
      requesterName: _text(json['requester_name']),
      assignedAt: _date(assignment['assigned_at']),
      assignedBy: _text(assignment['assigned_by']),
      report: _text(
        json['completion_note'] ??
            json['resolution_notes'] ??
            json['technical_completion_notes'],
      ),
      verificationNote: _text(json['verification_note']),
      verifiedAt: _date(json['verified_at']),
      equipment: _equipment(json['equipment']),
      safetyClass: switch (json['safety_classification']) {
        'requires_ptw' => 'Wajib izin kerja (PTW)',
        'requires_loto' => 'Wajib isolasi LOTO',
        'requires_ptw_and_loto' => 'Wajib PTW dan LOTO',
        _ => null,
      },
      requestNumber: _text(json['maintenance_request_number']),
      steps: _maps(
        json['checklist'] ?? json['tasks'],
      ).map(TaskStep.fromJson).toList(),
      labor: _maps(json['labor']).map(LaborInterval.fromJson).toList(),
      history: _maps(json['history']).map(TaskHistoryEntry.fromJson).toList(),
    );
  }

  final FieldTask task;
  final String? description;
  final String? requesterName;
  final DateTime? assignedAt;
  final String? assignedBy;

  /// The completion report already sent, if any.
  final String? report;

  /// GA's verdict on the report, once it has been verified.
  final String? verificationNote;
  final DateTime? verifiedAt;

  /// MTMS: the machine (with its tag), the safety precondition in words, and
  /// the maintenance request the order came from (UX-D14).
  final String? equipment;
  final String? safetyClass;
  final String? requestNumber;
  final List<TaskStep> steps;
  final List<LaborInterval> labor;
  final List<TaskHistoryEntry> history;
}

int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

String? _text(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse('$value')?.toLocal();

List<String> _strings(Object? value) =>
    value is List ? value.map((e) => '$e').toList() : const [];

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

String? _equipment(Object? value) {
  if (value is! Map) return null;
  final name = _text(value['name']);
  final tag = _text(value['tag']);
  if (name == null) return tag;
  return tag == null ? name : '$name ($tag)';
}
