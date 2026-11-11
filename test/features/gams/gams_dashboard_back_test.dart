import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/gams/data/models/gams_service_request.dart';
import 'package:esas/features/gams/data/models/gams_space_reservation.dart';
import 'package:esas/features/gams/data/models/gams_vehicle_booking.dart';
import 'package:esas/features/gams/data/models/gams_visitor_pass.dart';
import 'package:esas/features/gams/data/repositories/gams_repository.dart';
import 'package:esas/features/gams/presentation/controllers/gams_dashboard_controller.dart';
import 'package:esas/features/gams/presentation/views/gams_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements GamsRepository {}

/// GAMS-04. The app bar's back arrow called `Get.back()`, which closes an open
/// snackbar before it closes a page. With a section error on screen, the first
/// tap did nothing anybody could see.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('back leaves the page even while a snackbar is open', (
    tester,
  ) async {
    final repo = _Repo();
    when(repo.serviceRequests).thenAnswer((_) async => <GamsServiceRequest>[]);
    when(
      repo.spaceReservations,
    ).thenAnswer((_) async => <GamsSpaceReservation>[]);
    when(repo.vehicleBookings).thenAnswer((_) async => <GamsVehicleBooking>[]);
    when(repo.visits).thenAnswer((_) async => <GamsVisitorPass>[]);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Text('beranda')),
      ),
    );

    Get.put(GamsDashboardController(repository: repo));
    Get.to<void>(() => const GamsDashboardView());
    await tester.pumpAndSettle();
    expect(find.byType(GamsDashboardView), findsOneWidget);

    Get.snackbar(
      'Gagal',
      'Data tamu tidak dapat dimuat.',
      duration: const Duration(seconds: 30),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(GamsDashboardView), findsNothing);
    expect(find.text('beranda'), findsOneWidget);

    // Let the snackbar run out under fake time; awaiting its close here would
    // wait on an animation nothing pumps.
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
  });
}
