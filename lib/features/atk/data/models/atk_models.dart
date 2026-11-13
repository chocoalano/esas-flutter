import '../../../../core/utils/json_parsers.dart';

/// The server's label when it sends one; otherwise the Indonesian name of the
/// four states an ATK request can be in.
String atkStatusLabel(String status, String? serverLabel) =>
    serverLabel ??
    switch (status) {
      'requested' => 'Diajukan',
      'reserved' => 'Direservasi',
      'rejected' => 'Ditolak',
      'cancelled' => 'Dibatalkan',
      _ => status,
    };

/// One page of a list the server paginates, with whether more follow.
class AtkPage<T> {
  const AtkPage({
    required this.items,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  /// `{data: [...], meta: {current_page, last_page, total}}`. A paginator
  /// nested under `data` is read too.
  factory AtkPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final data = json['data'];
    final meta = data is Map ? asObject(data) : asObject(json['meta']);
    final rows = asModelList(asPage(data), fromJson);
    final current = asInt(meta['current_page']) ?? 1;

    return AtkPage(
      items: rows,
      currentPage: current,
      lastPage: asInt(meta['last_page']) ?? current,
      total: asInt(meta['total']) ?? rows.length,
    );
  }

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

/// A consumable the requester may ask for.
class AtkItem {
  const AtkItem({
    required this.id,
    required this.name,
    required this.unit,
    this.code,
  });

  factory AtkItem.fromJson(Map<String, dynamic> json) => AtkItem(
    id: asInt(json['id']) ?? 0,
    code: asString(json['code']),
    name: asString(json['name']) ?? 'Barang ATK',
    unit: asString(json['unit']) ?? 'pcs',
  );

  final int id;
  final String? code;
  final String name;
  final String unit;

  String get label => '$name ($unit)';
}

/// Where a request is picked up.
class AtkLocation {
  const AtkLocation({required this.id, required this.name, this.code});

  factory AtkLocation.fromJson(Map<String, dynamic> json) => AtkLocation(
    id: asInt(json['id']) ?? 0,
    code: asString(json['code']),
    name: asString(json['name']) ?? 'Gudang GA',
  );

  final int id;
  final String? code;
  final String name;
}

/// One of the requester's ATK requests, as the list shows it.
class AtkRequest {
  const AtkRequest({
    required this.id,
    required this.number,
    required this.itemName,
    required this.locationName,
    required this.quantity,
    required this.unit,
    required this.status,
    required this.statusLabel,
    this.issuedQuantity = 0,
    this.awaitingReceipt = false,
    this.createdAt,
  });

  factory AtkRequest.fromJson(Map<String, dynamic> json) {
    final status = asString(json['status']) ?? 'requested';

    return AtkRequest(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      itemName: asString(json['item_name']) ?? 'Barang ATK',
      locationName: asString(json['location_name']) ?? 'Gudang GA',
      quantity: asInt(json['quantity']) ?? 0,
      unit: asString(json['unit']) ?? 'pcs',
      status: status,
      statusLabel: atkStatusLabel(status, asString(json['status_label'])),
      issuedQuantity: asInt(json['issued_quantity']) ?? 0,
      awaitingReceipt: asBool(json['awaiting_receipt']) ?? false,
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final String number;
  final String itemName;
  final String locationName;
  final int quantity;
  final String unit;
  final String status;
  final String statusLabel;
  final int issuedQuantity;
  final bool awaitingReceipt;
  final String? createdAt;

  bool get isFullyIssued => quantity > 0 && issuedQuantity >= quantity;
}

/// One handover of goods against a request.
///
/// The requester's view carries [canAcknowledge]; the desk's carries
/// [receivedByName], [returnableQuantity] and [canReturn]. Both carry when it
/// was received, if it was, and how much of it came back. A server older than
/// returns sends none of those, which reads as nothing returned and nothing
/// returnable.
class AtkHandover {
  const AtkHandover({
    required this.id,
    required this.number,
    required this.quantity,
    this.issuedByName,
    this.issuedAt,
    this.receivedByName,
    this.receivedAt,
    this.canAcknowledge = false,
    this.returnedQuantity = 0,
    this.returnableQuantity = 0,
    this.canReturn = false,
  });

  factory AtkHandover.fromJson(Map<String, dynamic> json) => AtkHandover(
    id: asInt(json['id']) ?? 0,
    number: asString(json['number']) ?? '',
    quantity: asInt(json['quantity']) ?? 0,
    issuedByName: asString(json['issued_by_name']),
    issuedAt: asString(json['issued_at']),
    receivedByName: asString(json['received_by_name']),
    receivedAt: asString(json['received_at']),
    canAcknowledge: asBool(json['can_acknowledge']) ?? false,
    returnedQuantity: asInt(json['returned_quantity']) ?? 0,
    returnableQuantity: asInt(json['returnable_quantity']) ?? 0,
    canReturn: asBool(json['can_return']) ?? false,
  );

  final int id;
  final String number;
  final int quantity;
  final String? issuedByName;
  final String? issuedAt;
  final String? receivedByName;
  final String? receivedAt;
  final bool canAcknowledge;

  /// How much of this handover has come back so far.
  final int returnedQuantity;

  /// How much of it may still come back (desk only).
  final int returnableQuantity;

  /// The server lets the officer record a return against it (desk only).
  final bool canReturn;

  bool get isReceived => receivedAt != null;

  /// A return may be recorded: the server says so and something is left.
  bool get isReturnable => canReturn && returnableQuantity > 0;
}

/// Goods brought back against one handover.
class AtkReturn {
  const AtkReturn({
    required this.id,
    required this.number,
    required this.issueId,
    required this.quantity,
    this.reason,
    this.returnedByName,
    this.returnedAt,
  });

  factory AtkReturn.fromJson(Map<String, dynamic> json) => AtkReturn(
    id: asInt(json['id']) ?? 0,
    number: asString(json['number']) ?? '',
    issueId: asInt(json['issue_id']) ?? 0,
    quantity: asInt(json['quantity']) ?? 0,
    reason: asString(json['reason']),
    returnedByName: asString(json['returned_by_name']),
    returnedAt: asString(json['returned_at']),
  );

  final int id;
  final String number;
  final int issueId;
  final int quantity;
  final String? reason;
  final String? returnedByName;
  final String? returnedAt;
}

/// One of the requester's requests opened: what was asked, why it was refused
/// if it was, every handover and every return.
class AtkRequestDetail {
  const AtkRequestDetail({
    required this.id,
    required this.number,
    required this.itemName,
    required this.unit,
    required this.locationName,
    required this.quantity,
    required this.status,
    required this.statusLabel,
    this.reason,
    this.issuedQuantity = 0,
    this.issues = const [],
    this.returnedQuantity = 0,
    this.returns = const [],
    this.createdAt,
  });

  factory AtkRequestDetail.fromJson(Map<String, dynamic> json) {
    final status = asString(json['status']) ?? 'requested';

    return AtkRequestDetail(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      itemName: asString(json['item_name']) ?? 'Barang ATK',
      unit: asString(json['unit']) ?? 'pcs',
      locationName: asString(json['location_name']) ?? 'Gudang GA',
      quantity: asInt(json['quantity']) ?? 0,
      status: status,
      statusLabel: atkStatusLabel(status, asString(json['status_label'])),
      reason: asString(json['reason']),
      issuedQuantity: asInt(json['issued_quantity']) ?? 0,
      issues: asModelList(json['issues'], AtkHandover.fromJson),
      returnedQuantity: asInt(json['returned_quantity']) ?? 0,
      returns: asModelList(json['returns'], AtkReturn.fromJson),
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final String number;
  final String itemName;
  final String unit;
  final String locationName;
  final int quantity;
  final String status;
  final String statusLabel;
  final String? reason;
  final int issuedQuantity;
  final List<AtkHandover> issues;
  final int returnedQuantity;
  final List<AtkReturn> returns;
  final String? createdAt;

  bool get isFullyIssued => quantity > 0 && issuedQuantity >= quantity;

  bool get awaitsMyConfirmation => issues.any((issue) => issue.canAcknowledge);
}

/// The actions the desk may take on a request, as the server names them.
class AtkDeskAction {
  const AtkDeskAction._();

  static const reserve = 'reserve';
  static const reject = 'reject';
  static const issue = 'issue';
}

/// One request on the GA officer's desk.
class AtkDeskRequest {
  const AtkDeskRequest({
    required this.id,
    required this.number,
    required this.itemName,
    required this.unit,
    required this.locationName,
    required this.quantity,
    required this.status,
    required this.statusLabel,
    this.itemCode,
    this.lockVersion,
    this.createdAt,
    this.requesterName,
    this.allowedActions = const [],
  });

  factory AtkDeskRequest.fromJson(Map<String, dynamic> json) {
    final status = asString(json['status']) ?? 'requested';

    return AtkDeskRequest(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      itemName: asString(json['item_name']) ?? 'Barang ATK',
      itemCode: asString(json['item_code']),
      unit: asString(json['unit']) ?? 'pcs',
      locationName: asString(json['location_name']) ?? 'Gudang GA',
      quantity: asInt(json['quantity']) ?? 0,
      status: status,
      statusLabel: atkStatusLabel(status, asString(json['status_label'])),
      lockVersion: asInt(json['lock_version']),
      createdAt: asString(json['created_at']),
      requesterName: asString(json['requester_name']),
      allowedActions: [
        for (final action in asList(json['allowed_actions']))
          if (asString(action) case final name?) name,
      ],
    );
  }

  final int id;
  final String number;
  final String itemName;
  final String? itemCode;
  final String unit;
  final String locationName;
  final int quantity;
  final String status;
  final String statusLabel;
  final int? lockVersion;
  final String? createdAt;
  final String? requesterName;
  final List<String> allowedActions;

  bool get needsAction => allowedActions.isNotEmpty;

  bool allows(String action) => allowedActions.contains(action);
}

/// The balance of the requested item at the pickup location.
class AtkStock {
  const AtkStock({this.onHand = 0, this.reserved = 0, this.available = 0});

  factory AtkStock.fromJson(Map<String, dynamic> json) => AtkStock(
    onHand: asInt(json['on_hand']) ?? 0,
    reserved: asInt(json['reserved']) ?? 0,
    available: asInt(json['available']) ?? 0,
  );

  final int onHand;
  final int reserved;
  final int available;
}

/// One stock movement a request caused.
class AtkMovement {
  const AtkMovement({required this.command, required this.quantity, this.at});

  factory AtkMovement.fromJson(Map<String, dynamic> json) => AtkMovement(
    command: asString(json['command']) ?? '',
    quantity: asInt(json['quantity']) ?? 0,
    at: asString(json['at']),
  );

  final String command;
  final int quantity;
  final String? at;

  String get label => switch (command) {
    'receipt' => 'Penerimaan stok',
    'reserve' => 'Reservasi',
    'release' => 'Pelepasan reservasi',
    'issue' => 'Penyerahan',
    'return' => 'Pengembalian',
    'adjust' => 'Penyesuaian',
    _ => command,
  };
}

/// One request opened on the desk: the request, the stock behind it, its
/// handovers, returns and movements, and what the officer may do next.
class AtkDeskDetail {
  const AtkDeskDetail({
    required this.request,
    this.reason,
    this.issuedQuantity = 0,
    this.stock = const AtkStock(),
    this.issues = const [],
    this.movements = const [],
    this.returnedQuantity = 0,
    this.returns = const [],
  });

  factory AtkDeskDetail.fromJson(Map<String, dynamic> json) => AtkDeskDetail(
    request: AtkDeskRequest.fromJson(json),
    reason: asString(json['reason']),
    issuedQuantity: asInt(json['issued_quantity']) ?? 0,
    stock: AtkStock.fromJson(asObject(json['stock'])),
    issues: asModelList(json['issues'], AtkHandover.fromJson),
    movements: asModelList(json['movements'], AtkMovement.fromJson),
    returnedQuantity: asInt(json['returned_quantity']) ?? 0,
    returns: asModelList(json['returns'], AtkReturn.fromJson),
  );

  final AtkDeskRequest request;
  final String? reason;
  final int issuedQuantity;
  final AtkStock stock;
  final List<AtkHandover> issues;
  final List<AtkMovement> movements;
  final int returnedQuantity;
  final List<AtkReturn> returns;

  /// The handover with [id], if this request has it.
  AtkHandover? issueById(int id) {
    for (final issue in issues) {
      if (issue.id == id) return issue;
    }
    return null;
  }

  /// What is still to be handed over; never negative.
  int get remaining {
    final left = request.quantity - issuedQuantity;
    return left < 0 ? 0 : left;
  }
}
