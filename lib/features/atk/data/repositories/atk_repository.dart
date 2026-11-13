import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../../../core/utils/json_parsers.dart';
import '../models/atk_models.dart';

/// The ATK (office supplies) endpoints under `/gams`: the requester's own
/// requests and handovers, and the GA officer's desk.
///
/// The server scopes every read: a requester sees only their own requests, and
/// the desk answers 403 `DESK_NOT_ALLOWED` to anyone without the GAMS
/// inventory permission. Every write takes the Idempotency-Key the caller
/// minted for that intent, so a retry is answered rather than repeated.
class AtkRepository {
  const AtkRepository(this._client);

  final ApiClient _client;

  // ── Requester ─────────────────────────────────────────────────────────────

  Future<List<AtkItem>> items() async {
    final response = await _client.getObject(ApiRoutes.gamsInventoryItems);
    return asModelList(asPage(response['data']), AtkItem.fromJson);
  }

  Future<List<AtkLocation>> locations() async {
    final response = await _client.getObject(ApiRoutes.gamsInventoryLocations);
    return asModelList(asPage(response['data']), AtkLocation.fromJson);
  }

  Future<AtkPage<AtkRequest>> requests({int page = 1}) async {
    final response = await _client.getObject(
      ApiRoutes.gamsInventoryRequests,
      query: {'page': page},
    );
    return AtkPage.fromJson(response, AtkRequest.fromJson);
  }

  /// Files a request and answers its id and number.
  Future<({int id, String number})> createRequest({
    required int itemId,
    required int locationId,
    required int quantity,
    required String idempotencyKey,
  }) async {
    final response = await _client.postObject(
      ApiRoutes.gamsInventoryRequests,
      {'item_id': itemId, 'location_id': locationId, 'quantity': quantity},
      headers: IdempotencyKey.headerFor(idempotencyKey),
    );
    final data = asObject(response['data']);
    return (id: asInt(data['id']) ?? 0, number: asString(data['number']) ?? '');
  }

  Future<AtkRequestDetail> request(int id) async {
    final response = await _client.getObject(
      ApiRoutes.gamsInventoryRequest(id),
    );
    return AtkRequestDetail.fromJson(asObject(response['data']));
  }

  /// Confirms receiving one handover; answers the request as it now stands.
  Future<AtkRequestDetail> acknowledge({
    required int requestId,
    required int issueId,
    required String idempotencyKey,
  }) async {
    final response = await _client.postObject(
      ApiRoutes.gamsInventoryAcknowledge(requestId, issueId),
      const <String, dynamic>{},
      headers: IdempotencyKey.headerFor(idempotencyKey),
    );
    return AtkRequestDetail.fromJson(asObject(response['data']));
  }

  // ── GA officer's desk ─────────────────────────────────────────────────────

  /// Open requests (still waiting on GA), oldest first.
  Future<AtkPage<AtkDeskRequest>> desk({int page = 1}) async {
    final response = await _client.getObject(
      ApiRoutes.gamsInventoryDesk,
      query: {'page': page},
    );
    return AtkPage.fromJson(response, AtkDeskRequest.fromJson);
  }

  Future<AtkDeskDetail> deskRequest(int id) async {
    final response = await _client.getObject(
      ApiRoutes.gamsInventoryDeskRequest(id),
    );
    return AtkDeskDetail.fromJson(asObject(response['data']));
  }

  /// Sends one desk action (`reserve`, `reject`, `issue`) with [body]; answers
  /// the request as it now stands.
  Future<AtkDeskDetail> deskAct(
    int id,
    String action,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) async {
    final response = await _client.postObject(
      ApiRoutes.gamsInventoryDeskAction(id, action),
      body,
      headers: IdempotencyKey.headerFor(idempotencyKey),
    );
    return AtkDeskDetail.fromJson(asObject(response['data']));
  }

  /// Records [quantity] of handover [issueId] coming back, with why. Answers
  /// the request as it now stands and the server's sentence for it.
  ///
  /// Refused with 422 `EXCEEDS_ISSUED_QUANTITY` when more than is still
  /// returnable is sent.
  Future<({AtkDeskDetail detail, String message})> returnItems({
    required int requestId,
    required int issueId,
    required int quantity,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await _client.postObject(
      ApiRoutes.gamsInventoryDeskReturn(requestId, issueId),
      {'quantity': quantity, 'reason': reason},
      headers: IdempotencyKey.headerFor(idempotencyKey),
    );
    return (
      detail: AtkDeskDetail.fromJson(asObject(response['data'])),
      message: asString(response['message']) ?? 'Pengembalian barang dicatat.',
    );
  }
}
