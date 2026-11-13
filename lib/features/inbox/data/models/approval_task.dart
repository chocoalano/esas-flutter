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
    this.canReject = true,
    this.facts = const [],
    this.detailRoute,
    this.detailId,
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
      canReject: asBool(json['can_reject']) ?? true,
      facts: [
        for (final raw in asList(json['facts']))
          if ((
                asString(asObject(raw)['label']),
                asString(asObject(raw)['value']),
              )
              case (final String label, final String value))
            (label: label, value: value),
      ],
      detailRoute: asString(asObject(json['detail'])['route']),
      detailId: asInt(asObject(json['detail'])['id']),
    );
  }

  final String id;

  /// What the approver may see before deciding, as the server words it
  /// (UX-A08): kind, dates, duration, reason, the goods on a gate pass.
  final List<({String label, String value})> facts;

  /// False where the owning domain has no rejection for this item (a draft
  /// gate pass), so no button that is bound to fail is offered (FUNC-D19).
  final bool canReject;

  /// The screen that shows the whole request, when the app has one.
  final String? detailRoute;
  final int? detailId;

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
