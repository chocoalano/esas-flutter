import '../../../../core/utils/json_parsers.dart';

class ApprovalTask {
  const ApprovalTask({
    required this.id,
    required this.domain,
    required this.domainLabel,
    required this.itemId,
    required this.title,
    required this.requesterName,
    this.requesterNip,
    this.notes,
    required this.status,
    this.createdAt,
    this.actionUrl,
    this.canDecide = true,
  });

  factory ApprovalTask.fromJson(Map<String, dynamic> json) {
    return ApprovalTask(
      id: asString(json['id']) ?? '',
      domain: asString(json['domain']) ?? 'hrms',
      domainLabel: asString(json['domain_label']) ?? 'HRMS',
      itemId: asInt(json['item_id']) ?? 0,
      title: asString(json['title']) ?? '',
      requesterName: asString(json['requester_name']) ?? '',
      requesterNip: asString(json['requester_nip']),
      notes: asString(json['notes']),
      status: asString(json['status']) ?? 'waiting',
      createdAt: asString(json['created_at']),
      actionUrl: asString(json['action_url']),
      canDecide: asBool(json['can_decide']) ?? true,
    );
  }

  final String id;

  /// Whether this task can be decided from the app (INBOX-02). The server
  /// says no for an ITMS ticket, whose decision lives elsewhere; offering
  /// Setujui/Tolak there always ended in a 400. Absent means yes, as before.
  final bool canDecide;

  final String domain;
  final String domainLabel;
  final int itemId;
  final String title;
  final String requesterName;
  final String? requesterNip;
  final String? notes;
  final String status;
  final String? createdAt;
  final String? actionUrl;

  bool get isHrms => domain == 'hrms';
  bool get isGams => domain == 'gams';
  bool get isItms => domain == 'itms';
}
