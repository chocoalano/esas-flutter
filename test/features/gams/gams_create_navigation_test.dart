import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/gams/data/models/gams_service_request.dart';
import 'package:esas/features/gams/data/models/gams_space_reservation.dart';
import 'package:esas/features/gams/data/models/gams_vehicle_booking.dart';
import 'package:esas/features/gams/data/models/gams_visitor_pass.dart';
import 'package:esas/features/gams/data/repositories/gams_repository.dart';
import 'package:esas/features/gams/presentation/controllers/gams_create_controller.dart';
import 'package:esas/features/gams/presentation/controllers/gams_dashboard_controller.dart';
import 'package:esas/features/gams/presentation/routes/gams_routes.dart';
import 'package:esas/features/gams/presentation/views/gams_create_view.dart';
import 'package:esas/features/gams/presentation/views/gams_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements GamsRepository {}

/// UAT review H2. A filed request went "back" to the dashboard with
/// `Get.offNamed`, which stacked a SECOND dashboard on the first. The second
/// reused the first one's controller, so it never reloaded: the request just
/// filed was not on it, and Back led to another copy of the same page.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('a filed request returns to the one dashboard, reloaded', (
    tester,
  ) async {
    final repo = _Repo();
    var loads = 0;
    when(() => repo.serviceRequests()).thenAnswer((_) async {
      loads++;
      return <GamsServiceRequest>[];
    });
    when(
      () => repo.spaceReservations(),
    ).thenAnswer((_) async => <GamsSpaceReservation>[]);
    when(
      () => repo.vehicleBookings(),
    ).thenAnswer((_) async => <GamsVehicleBooking>[]);
    when(() => repo.visits()).thenAnswer((_) async => <GamsVisitorPass>[]);
    when(() => repo.definitions()).thenAnswer(
      (_) async => (
        definitions: const [
          GamsServiceDefinition(id: 3, title: 'Perbaikan AC', code: 'AC'),
        ],
        facilities: const <GamsFacility>[],
      ),
    );
    when(
      () => repo.createServiceRequest(
        serviceDefinitionId: any(named: 'serviceDefinitionId'),
        facilityId: any(named: 'facilityId'),
        subject: any(named: 'subject'),
        description: any(named: 'description'),
        priority: any(named: 'priority'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: '/home',
        getPages: [
          GetPage(
            name: '/home',
            page: () => const Scaffold(body: Text('BERANDA')),
          ),
          GetPage(name: GamsRoutes.gams, page: () => const GamsDashboardView()),
          GetPage(
            name: GamsRoutes.serviceRequests,
            page: () =>
                const GamsCreateView(kind: GamsCreateKind.serviceRequest),
          ),
        ],
      ),
    );
    Get.put(GamsDashboardController(repository: repo));
    Get.toNamed<void>(GamsRoutes.gams);
    await tester.pumpAndSettle();
    expect(loads, 1);

    final form = Get.put(
      GamsCreateController(
        repository: repo,
        kind: GamsCreateKind.serviceRequest,
      ),
      tag: GamsCreateKind.serviceRequest.name,
    );
    await tester.tap(find.text('Buat').first);
    await tester.pumpAndSettle();
    form.optionId.value = 3;
    form.subjectC.text = 'AC ruang rapat mati';

    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    expect(find.byType(GamsDashboardView, skipOffstage: false), findsOneWidget);
    expect(loads, 2, reason: 'the dashboard shows what was just filed');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
