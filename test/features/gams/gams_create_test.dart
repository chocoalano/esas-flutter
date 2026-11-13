import 'package:esas/core/network/api_exception.dart';
import 'dart:async';

import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/features/gams/data/models/gams_service_request.dart';
import 'package:esas/features/gams/data/models/gams_space_reservation.dart';
import 'package:esas/features/gams/data/models/gams_vehicle_booking.dart';
import 'package:esas/features/gams/data/repositories/gams_repository.dart';
import 'package:esas/features/gams/presentation/controllers/gams_create_controller.dart';
import 'package:esas/features/gams/presentation/routes/gams_pages.dart';
import 'package:esas/features/gams/presentation/routes/gams_routes.dart';
import 'package:esas/features/gams/presentation/views/gams_create_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements GamsRepository {}

/// GAMS-01. Every "Buat / Pesan / Pinjam / Daftar" button and the four GAMS
/// tiles on the home screen opened the same dashboard: nothing could be
/// requested, reserved, booked or registered from the app at all.
void main() {
  late _Repo repo;

  const definitions = [
    GamsServiceDefinition(id: 3, title: 'Perbaikan AC', code: 'AC'),
  ];
  const facilities = [GamsFacility(id: 9, name: 'Gedung A', code: 'A')];

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
    when(() => repo.definitions()).thenAnswer(
      (_) async => (definitions: definitions, facilities: facilities),
    );
    when(() => repo.spaces()).thenAnswer(
      (_) async => const [
        GamsSpace(
          id: 5,
          name: 'Ruang Rapat 1',
          code: 'R1',
          kind: 'Meeting Room',
        ),
      ],
    );
    when(() => repo.vehicles()).thenAnswer(
      (_) async => const [GamsVehicle(id: 7, number: 'B 1 AB', name: 'Avanza')],
    );
  });

  tearDown(Get.reset);

  Future<GamsCreateController> open(GamsCreateKind kind) async {
    final controller = GamsCreateController(repository: repo, kind: kind);
    controller.onInit();
    await pumpEventQueue();
    return controller;
  }

  test('each create route opens its own form', () {
    final byRoute = {
      for (final page in GamsPages.pages) page.name: page.page(),
    };

    expect(byRoute[GamsRoutes.serviceRequests], isA<GamsCreateView>());
    expect(byRoute[GamsRoutes.spaceReservations], isA<GamsCreateView>());
    expect(byRoute[GamsRoutes.vehicleBookings], isA<GamsCreateView>());
    expect(byRoute[GamsRoutes.visitorPasses], isA<GamsCreateView>());
    expect({
      for (final route in [
        GamsRoutes.serviceRequests,
        GamsRoutes.spaceReservations,
        GamsRoutes.vehicleBookings,
        GamsRoutes.visitorPasses,
      ])
        (byRoute[route]! as GamsCreateView).kind,
    }, hasLength(4));
  });

  group('a service request', () {
    setUp(() {
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
    });

    test('is not sent without a service and a subject', () async {
      final controller = await open(GamsCreateKind.serviceRequest);

      expect(await controller.submit(), isFalse);
      expect(controller.error.value, isNotNull);
      verifyNever(
        () => repo.createServiceRequest(
          serviceDefinitionId: any(named: 'serviceDefinitionId'),
          facilityId: any(named: 'facilityId'),
          subject: any(named: 'subject'),
          description: any(named: 'description'),
          priority: any(named: 'priority'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    test('is sent once, with what was filled in', () async {
      final pending = Completer<void>();
      when(
        () => repo.createServiceRequest(
          serviceDefinitionId: any(named: 'serviceDefinitionId'),
          facilityId: any(named: 'facilityId'),
          subject: any(named: 'subject'),
          description: any(named: 'description'),
          priority: any(named: 'priority'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) => pending.future);
      final controller = await open(GamsCreateKind.serviceRequest);
      controller.optionId.value = 3;
      controller.facilityId.value = 9;
      controller.subjectC.text = 'AC bocor';

      final first = controller.submit();
      final second = controller.submit();
      pending.complete();

      expect(await first, isTrue);
      expect(await second, isFalse);
      verify(
        () => repo.createServiceRequest(
          serviceDefinitionId: 3,
          facilityId: 9,
          subject: 'AC bocor',
          description: any(named: 'description'),
          priority: 'medium',
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    });
  });

  group('a room reservation', () {
    setUp(() {
      when(
        () => repo.createSpaceReservation(
          spaceId: any(named: 'spaceId'),
          startAt: any(named: 'startAt'),
          endAt: any(named: 'endAt'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async {});
    });

    test('must end after it starts', () async {
      final controller = await open(GamsCreateKind.spaceReservation);
      controller.optionId.value = 5;
      controller.startAt.value = DateTime(2026, 11, 12, 10);
      controller.endAt.value = DateTime(2026, 11, 12, 9);

      expect(await controller.submit(), isFalse);
      expect(controller.error.value, contains('setelah'));
    });

    test('is sent with the workspace offset on both ends', () async {
      final previous = WorkspaceClock.current;
      addTearDown(() => WorkspaceClock.current = previous);
      WorkspaceClock.current = WorkspaceClock.fallback(); // WIB, +07:00

      final controller = await open(GamsCreateKind.spaceReservation);
      controller.optionId.value = 5;
      controller.startAt.value = DateTime(2026, 11, 12, 9);
      controller.endAt.value = DateTime(2026, 11, 12, 10, 30);

      expect(await controller.submit(), isTrue);
      verify(
        () => repo.createSpaceReservation(
          spaceId: 5,
          startAt: '2026-11-12T09:00:00+07:00',
          endAt: '2026-11-12T10:30:00+07:00',
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    });
  });

  test('a vehicle booking carries its purpose and times', () async {
    when(
      () => repo.createVehicleBooking(
        vehicleId: any(named: 'vehicleId'),
        purpose: any(named: 'purpose'),
        startsAt: any(named: 'startsAt'),
        endsAt: any(named: 'endsAt'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {});
    final controller = await open(GamsCreateKind.vehicleBooking);
    controller.optionId.value = 7;
    controller.subjectC.text = 'Kunjungan klien';
    controller.startAt.value = DateTime(2026, 11, 12, 13);
    controller.endAt.value = DateTime(2026, 11, 12, 17);

    expect(await controller.submit(), isTrue);
    verify(
      () => repo.createVehicleBooking(
        vehicleId: 7,
        purpose: 'Kunjungan klien',
        startsAt: any(named: 'startsAt'),
        endsAt: any(named: 'endsAt'),
        // FUNC-A04: a retry replays the first booking.
        idempotencyKey: any(named: 'idempotencyKey', that: isNotNull),
      ),
    ).called(1);
  });

  test('a visitor needs a building, a name and a purpose', () async {
    when(
      () => repo.createVisit(
        facilityId: any(named: 'facilityId'),
        visitorName: any(named: 'visitorName'),
        visitorPhone: any(named: 'visitorPhone'),
        visitorCompany: any(named: 'visitorCompany'),
        visitorIdNumber: any(named: 'visitorIdNumber'),
        purpose: any(named: 'purpose'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {});
    final controller = await open(GamsCreateKind.visit);

    expect(controller.facilities, hasLength(1));
    expect(await controller.submit(), isFalse);

    controller.facilityId.value = 9;
    controller.visitorNameC.text = 'Budi';
    controller.subjectC.text = 'Rapat vendor';

    expect(await controller.submit(), isTrue);
    verify(
      () => repo.createVisit(
        facilityId: 9,
        visitorName: 'Budi',
        visitorPhone: any(named: 'visitorPhone'),
        visitorCompany: any(named: 'visitorCompany'),
        visitorIdNumber: any(named: 'visitorIdNumber'),
        purpose: 'Rapat vendor',
        idempotencyKey: any(named: 'idempotencyKey', that: isNotNull),
      ),
    ).called(1);
  });

  test(
    'options that fail to load offer a retry, not an empty form (UX-A07)',
    () async {
      var fail = true;
      when(() => repo.spaces()).thenAnswer((_) async {
        if (fail) throw const ApiException('Server tidak dapat dihubungi');
        return const [
          GamsSpace(
            id: 5,
            name: 'Ruang Rapat 1',
            code: 'R1',
            kind: 'Meeting Room',
          ),
        ];
      });
      final controller = await open(GamsCreateKind.spaceReservation);

      expect(
        controller.loadError.value?.message,
        'Server tidak dapat dihubungi',
      );
      expect(controller.error.value, isNull);

      fail = false;
      await controller.loadOptions();
      expect(controller.loadError.value, isNull);
      expect(controller.spaces, hasLength(1));
    },
  );
}
