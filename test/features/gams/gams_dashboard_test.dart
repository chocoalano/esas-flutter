import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/gams/data/models/gams_service_request.dart';
import 'package:esas/features/gams/data/models/gams_space_reservation.dart';
import 'package:esas/features/gams/data/models/gams_vehicle_booking.dart';
import 'package:esas/features/gams/data/models/gams_visitor_pass.dart';
import 'package:esas/features/gams/data/repositories/gams_repository.dart';
import 'package:esas/features/gams/presentation/controllers/gams_dashboard_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements GamsRepository {}

/// GAMS-02. Four requests, one after another, in one `try`: a 403 on the
/// visitor book hid the three sections that had loaded, and "Coba Lagi" failed
/// the same way every time.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('one section failing leaves the others on screen', () async {
    final repo = _Repo();
    when(() => repo.serviceRequests()).thenAnswer(
      (_) async => [
        GamsServiceRequest.fromJson({'id': 1, 'subject': 'AC'}),
      ],
    );
    when(
      () => repo.spaceReservations(),
    ).thenAnswer((_) async => <GamsSpaceReservation>[]);
    when(
      () => repo.vehicleBookings(),
    ).thenAnswer((_) async => <GamsVehicleBooking>[]);
    when(
      () => repo.visits(),
    ).thenThrow(const ApiException('Tidak diizinkan.', status: 403));

    final controller = GamsDashboardController(repository: repo);
    await controller.loadDashboard();

    expect(controller.error.value, isNull);
    expect(controller.serviceRequests, hasLength(1));
    expect(controller.sectionErrors['visits']?.status, 403);
    expect(controller.sectionErrors.containsKey('serviceRequests'), isFalse);
  });

  test('everything failing is one error for the screen', () async {
    final repo = _Repo();
    const offline = ApiException('Offline', code: 'network_unreachable');
    when(() => repo.serviceRequests()).thenThrow(offline);
    when(() => repo.spaceReservations()).thenThrow(offline);
    when(() => repo.vehicleBookings()).thenThrow(offline);
    when(() => repo.visits()).thenThrow(offline);

    final controller = GamsDashboardController(repository: repo);
    await controller.loadDashboard();

    expect(controller.error.value, isNotNull);
  });

  // GAMS-03. "N pengajuan aktif" counted resolved and closed requests too,
  // and every count stopped at the 20 rows of the first page.
  test('active means open, and a full page is not the total', () async {
    final repo = _Repo();
    when(() => repo.serviceRequests()).thenAnswer(
      (_) async => [
        GamsServiceRequest.fromJson({'id': 1, 'status': 'resolved'}),
        GamsServiceRequest.fromJson({'id': 2, 'status': 'closed'}),
        GamsServiceRequest.fromJson({'id': 3, 'status': 'open'}),
      ],
    );
    when(
      () => repo.spaceReservations(),
    ).thenAnswer((_) async => <GamsSpaceReservation>[]);
    when(
      () => repo.vehicleBookings(),
    ).thenAnswer((_) async => <GamsVehicleBooking>[]);
    when(() => repo.visits()).thenAnswer((_) async => <GamsVisitorPass>[]);

    final controller = GamsDashboardController(repository: repo);
    await controller.loadDashboard();

    expect(controller.activeServiceRequests, 1);
    expect(GamsDashboardController.countLabel(3, loaded: 3), '3');
    expect(GamsDashboardController.countLabel(20, loaded: 20), '20+');
  });
}
