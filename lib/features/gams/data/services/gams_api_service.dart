import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/idempotency_key.dart';

class GamsApiService {
  const GamsApiService(this._client);

  final ApiClient _client;

  // ── Service Requests ──
  Future<Map<String, dynamic>> serviceDefinitions() =>
      _client.getObject(ApiRoutes.gamsServiceDefinitions);

  Future<Map<String, dynamic>> serviceRequests({int page = 1}) =>
      _client.getObject(
        ApiRoutes.gamsServiceRequests,
        query: {'page': page, 'per_page': 20},
      );

  Future<Map<String, dynamic>> serviceRequest(int id) =>
      _client.getObject(ApiRoutes.gamsServiceRequest(id));

  Future<Map<String, dynamic>> createServiceRequest({
    required int serviceDefinitionId,
    int? facilityId,
    required String subject,
    String? description,
    String priority = 'medium',
    Map<String, Object?>? fields,
    String? idempotencyKey,
  }) => _client.postObject(
    ApiRoutes.gamsServiceRequests,
    {
      'service_definition_id': serviceDefinitionId,
      if (facilityId != null) 'facility_id': facilityId,
      'subject': subject,
      if (description != null) 'description': description,
      'priority': priority,
      if (fields != null && fields.isNotEmpty) 'fields': fields,
    },
    headers: IdempotencyKey.headerFor(idempotencyKey),
  );

  // ── Space Reservations ──
  Future<Map<String, dynamic>> spaces() =>
      _client.getObject(ApiRoutes.gamsSpaces);

  Future<Map<String, dynamic>> spaceReservations({int page = 1}) =>
      _client.getObject(
        ApiRoutes.gamsSpaceReservations,
        query: {'page': page, 'per_page': 20},
      );

  Future<Map<String, dynamic>> createSpaceReservation({
    required int spaceId,
    required String startAt,
    required String endAt,
    String? idempotencyKey,
  }) => _client.postObject(
    ApiRoutes.gamsSpaceReservations,
    {'space_id': spaceId, 'start_at': startAt, 'end_at': endAt},
    headers: IdempotencyKey.headerFor(idempotencyKey),
  );

  Future<Map<String, dynamic>> cancelSpaceReservation(
    int id, {
    String? reason,
    String? idempotencyKey,
  }) => _client.deleteObject(
    ApiRoutes.gamsSpaceReservation(id),
    query: {if (reason != null) 'reason': reason},
    headers: IdempotencyKey.headerFor(idempotencyKey),
  );

  /// The requester withdraws their own service request (D-06).
  Future<Map<String, dynamic>> cancelServiceRequest(
    int id, {
    required String reason,
    String? idempotencyKey,
  }) => _client.postObject(
    '${ApiRoutes.gamsServiceRequests}/$id/cancel',
    {'reason': reason},
    headers: IdempotencyKey.headerFor(idempotencyKey),
  );

  // ── Vehicle Bookings ──
  Future<Map<String, dynamic>> vehicles() =>
      _client.getObject(ApiRoutes.gamsVehicles);

  Future<Map<String, dynamic>> vehicleBookings({int page = 1}) =>
      _client.getObject(
        ApiRoutes.gamsVehicleBookings,
        query: {'page': page, 'per_page': 20},
      );

  Future<Map<String, dynamic>> createVehicleBooking({
    required int vehicleId,
    required String purpose,
    required String startsAt,
    required String endsAt,
    String? idempotencyKey,
  }) => _client.postObject(
    ApiRoutes.gamsVehicleBookings,
    {
      'vehicle_id': vehicleId,
      'purpose': purpose,
      'starts_at': startsAt,
      'ends_at': endsAt,
    },
    headers: IdempotencyKey.headerFor(idempotencyKey),
  );

  Future<Map<String, dynamic>> cancelVehicleBooking(
    int id, {
    String? reason,
    String? idempotencyKey,
  }) => _client.deleteObject(
    ApiRoutes.gamsVehicleBooking(id),
    query: {if (reason != null) 'reason': reason},
    headers: IdempotencyKey.headerFor(idempotencyKey),
  );

  // ── Visitor Passes ──
  Future<Map<String, dynamic>> visits({int page = 1}) => _client.getObject(
    ApiRoutes.gamsVisits,
    query: {'page': page, 'per_page': 20},
  );

  Future<Map<String, dynamic>> createVisit({
    required int facilityId,
    required String visitorName,
    String? visitorPhone,
    String? visitorCompany,
    String? visitorIdNumber,
    required String purpose,
    String? idempotencyKey,
  }) => _client.postObject(ApiRoutes.gamsVisits, {
    'facility_id': facilityId,
    'visitor_name': visitorName,
    if (visitorPhone != null) 'visitor_phone': visitorPhone,
    if (visitorCompany != null) 'visitor_company': visitorCompany,
    if (visitorIdNumber != null) 'visitor_id_number': visitorIdNumber,
    'purpose': purpose,
  }, headers: IdempotencyKey.headerFor(idempotencyKey));

  // ── Packages / Mailroom ──
  Future<Map<String, dynamic>> packages({int page = 1}) => _client.getObject(
    ApiRoutes.gamsPackages,
    query: {'page': page, 'per_page': 20},
  );

  // ── Gate Passes ──
  Future<Map<String, dynamic>> gatePasses({int page = 1}) => _client.getObject(
    ApiRoutes.gamsGatePasses,
    query: {'page': page, 'per_page': 20},
  );

  Future<Map<String, dynamic>> createGatePass({
    required int facilityId,
    required List<Map<String, dynamic>> items,
  }) => _client.postObject(ApiRoutes.gamsGatePasses, {
    'facility_id': facilityId,
    'items': items,
  });

  // ── Parking Permits ──
  Future<Map<String, dynamic>> parkingAreas() =>
      _client.getObject(ApiRoutes.gamsParkingAreas);

  Future<Map<String, dynamic>> parkingPermits({int page = 1}) =>
      _client.getObject(
        ApiRoutes.gamsParkingPermits,
        query: {'page': page, 'per_page': 20},
      );

  Future<Map<String, dynamic>> createParkingPermit({
    required int parkingAreaId,
    required String licensePlate,
  }) => _client.postObject(ApiRoutes.gamsParkingPermits, {
    'parking_area_id': parkingAreaId,
    'license_plate': licensePlate,
  });

  // ── Office Supplies / Inventory Requests ──
  Future<Map<String, dynamic>> inventoryItems() =>
      _client.getObject(ApiRoutes.gamsInventoryItems);

  Future<Map<String, dynamic>> inventoryRequests({int page = 1}) =>
      _client.getObject(
        ApiRoutes.gamsInventoryRequests,
        query: {'page': page, 'per_page': 20},
      );

  Future<Map<String, dynamic>> createInventoryRequest({
    required int itemId,
    required int locationId,
    required int quantity,
  }) => _client.postObject(ApiRoutes.gamsInventoryRequests, {
    'item_id': itemId,
    'location_id': locationId,
    'quantity': quantity,
  });

  // ── Security Incidents ──
  Future<Map<String, dynamic>> securityIncidents({int page = 1}) =>
      _client.getObject(
        ApiRoutes.gamsSecurityIncidents,
        query: {'page': page, 'per_page': 20},
      );

  Future<Map<String, dynamic>> createSecurityIncident({
    required int facilityId,
    required String title,
    required String description,
    required String occurredAt,
  }) => _client.postObject(ApiRoutes.gamsSecurityIncidents, {
    'facility_id': facilityId,
    'title': title,
    'description': description,
    'occurred_at': occurredAt,
  });

  // ── Key Register ──
  Future<Map<String, dynamic>> keyRegisters({int page = 1}) =>
      _client.getObject(
        ApiRoutes.gamsKeyRegisters,
        query: {'page': page, 'per_page': 20},
      );

  // ── Field Work Orders ──
  Future<Map<String, dynamic>> myWorkOrders({int page = 1}) =>
      _client.getObject(
        ApiRoutes.gamsMyWorkOrders,
        query: {'page': page, 'per_page': 20},
      );

  Future<Map<String, dynamic>> completeWorkOrder(
    int id, {
    required String completionNotes,
  }) => _client.postObject(ApiRoutes.gamsCompleteWorkOrder(id), {
    'completion_notes': completionNotes,
  });
}
