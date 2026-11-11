import '../../../../core/utils/json_parsers.dart';
import '../models/gams_package.dart';
import '../models/gams_service_request.dart';
import '../models/gams_space_reservation.dart';
import '../models/gams_vehicle_booking.dart';
import '../models/gams_visitor_pass.dart';
import '../models/gate_pass.dart';
import '../models/inventory_request.dart';
import '../models/parking_permit.dart';
import '../services/gams_api_service.dart';

class GamsRepository {
  const GamsRepository(this._api);

  final GamsApiService _api;

  // ── Service Requests ──
  Future<
    ({List<GamsServiceDefinition> definitions, List<GamsFacility> facilities})
  >
  definitions() async {
    final response = await _api.serviceDefinitions();
    final defs = asList(
      response['definitions'],
    ).map((item) => GamsServiceDefinition.fromJson(asObject(item))).toList();
    final facs = asList(
      response['facilities'],
    ).map((item) => GamsFacility.fromJson(asObject(item))).toList();
    return (definitions: defs, facilities: facs);
  }

  Future<List<GamsServiceRequest>> serviceRequests({int page = 1}) async {
    final response = await _api.serviceRequests(page: page);
    final data = asList(response['data']);
    return data
        .map((item) => GamsServiceRequest.fromJson(asObject(item)))
        .toList();
  }

  Future<void> createServiceRequest({
    required int serviceDefinitionId,
    int? facilityId,
    required String subject,
    String? description,
    String priority = 'medium',
    String? idempotencyKey,
  }) async {
    await _api.createServiceRequest(
      serviceDefinitionId: serviceDefinitionId,
      facilityId: facilityId,
      subject: subject,
      description: description,
      priority: priority,
      idempotencyKey: idempotencyKey,
    );
  }

  // ── Space Reservations ──
  Future<List<GamsSpace>> spaces() async {
    final response = await _api.spaces();
    final data = asList(response['data']);
    return data.map((item) => GamsSpace.fromJson(asObject(item))).toList();
  }

  Future<List<GamsSpaceReservation>> spaceReservations({int page = 1}) async {
    final response = await _api.spaceReservations(page: page);
    final data = asList(response['data']);
    return data
        .map((item) => GamsSpaceReservation.fromJson(asObject(item)))
        .toList();
  }

  Future<void> createSpaceReservation({
    required int spaceId,
    required String startAt,
    required String endAt,
    String? idempotencyKey,
  }) async {
    await _api.createSpaceReservation(
      spaceId: spaceId,
      startAt: startAt,
      endAt: endAt,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<void> cancelSpaceReservation(int id, {String? reason}) =>
      _api.cancelSpaceReservation(id, reason: reason);

  // ── Vehicle Bookings ──
  Future<List<GamsVehicle>> vehicles() async {
    final response = await _api.vehicles();
    final data = asList(response['data']);
    return data.map((item) => GamsVehicle.fromJson(asObject(item))).toList();
  }

  Future<List<GamsVehicleBooking>> vehicleBookings({int page = 1}) async {
    final response = await _api.vehicleBookings(page: page);
    final data = asList(response['data']);
    return data
        .map((item) => GamsVehicleBooking.fromJson(asObject(item)))
        .toList();
  }

  Future<void> createVehicleBooking({
    required int vehicleId,
    required String purpose,
    required String startsAt,
    required String endsAt,
  }) => _api.createVehicleBooking(
    vehicleId: vehicleId,
    purpose: purpose,
    startsAt: startsAt,
    endsAt: endsAt,
  );

  Future<void> cancelVehicleBooking(int id, {String? reason}) =>
      _api.cancelVehicleBooking(id, reason: reason);

  // ── Visitor Passes ──
  Future<List<GamsVisitorPass>> visits({int page = 1}) async {
    final response = await _api.visits(page: page);
    final data = asList(response['data']);
    return data
        .map((item) => GamsVisitorPass.fromJson(asObject(item)))
        .toList();
  }

  Future<void> createVisit({
    required int facilityId,
    required String visitorName,
    String? visitorPhone,
    String? visitorCompany,
    String? visitorIdNumber,
    required String purpose,
  }) => _api.createVisit(
    facilityId: facilityId,
    visitorName: visitorName,
    visitorPhone: visitorPhone,
    visitorCompany: visitorCompany,
    visitorIdNumber: visitorIdNumber,
    purpose: purpose,
  );

  // ── Packages ──
  Future<List<GamsPackage>> packages({int page = 1}) async {
    final response = await _api.packages(page: page);
    final data = asList(response['data']);
    return data.map((item) => GamsPackage.fromJson(asObject(item))).toList();
  }

  // ── Gate Passes ──
  Future<List<GatePass>> gatePasses({int page = 1}) async {
    final response = await _api.gatePasses(page: page);
    final data = asList(response['data']);
    return data.map((item) => GatePass.fromJson(asObject(item))).toList();
  }

  Future<void> createGatePass({
    required int facilityId,
    required List<Map<String, dynamic>> items,
  }) => _api.createGatePass(facilityId: facilityId, items: items);

  // ── Parking Permits ──
  Future<List<ParkingPermit>> parkingPermits({int page = 1}) async {
    final response = await _api.parkingPermits(page: page);
    final data = asList(response['data']);
    return data.map((item) => ParkingPermit.fromJson(asObject(item))).toList();
  }

  Future<void> createParkingPermit({
    required int parkingAreaId,
    required String licensePlate,
  }) => _api.createParkingPermit(
    parkingAreaId: parkingAreaId,
    licensePlate: licensePlate,
  );

  // ── Inventory Requests ──
  Future<List<InventoryRequest>> inventoryRequests({int page = 1}) async {
    final response = await _api.inventoryRequests(page: page);
    final data = asList(response['data']);
    return data
        .map((item) => InventoryRequest.fromJson(asObject(item)))
        .toList();
  }

  Future<void> createInventoryRequest({
    required int itemId,
    required int locationId,
    required int quantity,
  }) => _api.createInventoryRequest(
    itemId: itemId,
    locationId: locationId,
    quantity: quantity,
  );

  // ── Security Incidents ──
  Future<void> createSecurityIncident({
    required int facilityId,
    required String title,
    required String description,
    required String occurredAt,
  }) => _api.createSecurityIncident(
    facilityId: facilityId,
    title: title,
    description: description,
    occurredAt: occurredAt,
  );
}
