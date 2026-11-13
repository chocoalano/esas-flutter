import '../../../core/config/api_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/utils/json_parsers.dart';

/// A piece of plant equipment a damage report can name.
class MtmsEquipment {
  const MtmsEquipment({required this.id, required this.name, this.tag});

  factory MtmsEquipment.fromJson(Map<String, dynamic> json) => MtmsEquipment(
    id: asInt(json['id']) ?? 0,
    name: asString(json['name']) ?? '',
    tag: asString(json['equipment_tag']),
  );

  final int id;
  final String name;
  final String? tag;

  String get label => tag == null || tag!.isEmpty ? name : '$name ($tag)';
}

/// One damage report the employee filed, and the work it led to (FUNC-D02).
class MtmsReport {
  const MtmsReport({
    required this.id,
    required this.number,
    required this.symptom,
    required this.status,
    required this.statusLabel,
    this.severity,
    this.equipmentName,
    this.equipmentTag,
    this.rejectionReason,
    this.workOrderNumber,
    this.workOrderStatusLabel,
    this.createdAt,
  });

  factory MtmsReport.fromJson(Map<String, dynamic> json) {
    final workOrder = asObject(json['work_order']);
    final status = asString(json['status']) ?? 'submitted';

    return MtmsReport(
      id: asInt(json['id']) ?? 0,
      number: asString(json['request_number']) ?? '',
      symptom: asString(json['symptom']) ?? '',
      status: status,
      statusLabel: asString(json['status_label']) ?? status,
      severity: asString(json['severity']),
      equipmentName: asString(json['equipment_name']),
      equipmentTag: asString(json['equipment_tag']),
      rejectionReason: asString(json['rejection_reason']),
      workOrderNumber: asString(workOrder['number']),
      workOrderStatusLabel: asString(workOrder['status_label']),
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final String number;
  final String symptom;
  final String status;
  final String statusLabel;
  final String? severity;
  final String? equipmentName;
  final String? equipmentTag;
  final String? rejectionReason;
  final String? workOrderNumber;
  final String? workOrderStatusLabel;
  final String? createdAt;
}

/// The MTMS requester endpoints: equipment to pick, one's own reports, and
/// filing one. The server scopes every read to the caller.
class MtmsReportsRepository {
  const MtmsReportsRepository(this._client);

  final ApiClient _client;

  Future<List<MtmsEquipment>> equipment() async {
    final response = await _client.getObject(ApiRoutes.mtmsEquipment);
    return [
      for (final item in asList(response['data']))
        MtmsEquipment.fromJson(asObject(item)),
    ];
  }

  Future<({List<MtmsReport> reports, int lastPage})> reports({
    int page = 1,
  }) async {
    final response = await _client.getObject(
      ApiRoutes.mtmsMaintenanceRequests,
      query: {'page': page},
    );
    // The list arrives as a paginator under `data`.
    final data = response['data'];
    final rows = data is Map ? asList(data['data']) : asList(data);
    final meta = asObject(response['meta']);

    return (
      reports: [for (final row in rows) MtmsReport.fromJson(asObject(row))],
      lastPage: asInt(meta['last_page']) ?? 1,
    );
  }

  /// Files a report. [idempotencyKey] names the attempt: a retry with the
  /// same key returns the first answer instead of a second report.
  Future<({int id, String number})> file({
    required int equipmentId,
    required String symptom,
    required String severity,
    required String idempotencyKey,
  }) async {
    final response = await _client.postObject(
      ApiRoutes.mtmsMaintenanceRequests,
      {'equipment_id': equipmentId, 'symptom': symptom, 'severity': severity},
      headers: IdempotencyKey.headerFor(idempotencyKey),
    );
    final data = asObject(response['data']);
    return (
      id: asInt(data['id']) ?? 0,
      number: asString(data['request_number']) ?? '',
    );
  }
}
