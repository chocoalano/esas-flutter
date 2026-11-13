import 'package:esas/features/gams/data/models/gams_service_request.dart';
import 'package:esas/features/gams/data/repositories/gams_repository.dart';
import 'package:esas/features/gams/presentation/controllers/gams_create_controller.dart';
import 'package:esas/features/gams/presentation/widgets/gams_service_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements GamsRepository {}

/// FUNC-A01. A GA service with a required field was accepted on the phone and
/// refused by the server, because the app never asked for — or sent — it.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _Repo repo;

  final roomLayout = GamsServiceDefinition.fromJson({
    'id': 3,
    'title': 'Penataan ruang rapat',
    'code': 'ROOM',
    'requires_description': true,
    'requires_facility': false,
    'fields': [
      {
        'key': 'preferred_schedule',
        'label': 'Tanggal yang diinginkan',
        'type': 'date',
        'required': true,
        'options': null,
      },
      {
        'key': 'layout',
        'label': 'Layout',
        'type': 'select',
        'required': true,
        'options': ['Kelas', 'U-Shape'],
      },
      {
        'key': 'attendee_count',
        'label': 'Jumlah peserta',
        'type': 'number',
        'required': false,
        'options': null,
      },
    ],
  });
  const plain = GamsServiceDefinition(id: 4, title: 'Perbaikan', code: 'FIX');
  final undrawable = GamsServiceDefinition.fromJson({
    'id': 5,
    'title': 'Tanda tangan',
    'code': 'SIGN',
    'fields': [
      {
        'key': 'signature',
        'label': 'TTD',
        'type': 'hologram',
        'required': true,
      },
    ],
  });

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
    when(() => repo.definitions()).thenAnswer(
      (_) async => (
        definitions: [roomLayout, plain, undrawable],
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
        fields: any(named: 'fields'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(Get.reset);

  Future<GamsCreateController> open() async {
    final controller = GamsCreateController(
      repository: repo,
      kind: GamsCreateKind.serviceRequest,
    );
    controller.onInit();
    await pumpEventQueue();
    return controller;
  }

  test(
    'the server\'s form is read, and a service the app cannot draw is not offered',
    () async {
      final controller = await open();

      expect(roomLayout.fields.map((f) => f.type), [
        GamsFieldType.date,
        GamsFieldType.select,
        GamsFieldType.number,
      ]);
      expect(roomLayout.fields[1].options, ['Kelas', 'U-Shape']);
      expect(controller.definitions.map((d) => d.id), [3, 4]);
    },
  );

  test(
    'a required field, the description the service needs, and nothing else block sending',
    () async {
      final controller = await open();
      controller.optionId.value = 3;
      controller.subjectC.text = 'Rapat direksi';

      expect(controller.validate(), 'Layanan ini memerlukan keterangan.');

      controller.descriptionC.text = '20 kursi';
      expect(controller.validate(), 'Isi "Tanggal yang diinginkan".');

      controller.setField('preferred_schedule', DateTime(2026, 11, 20));
      expect(controller.validate(), 'Isi "Layout".');

      controller.setField('layout', 'U-Shape');
      expect(controller.validate(), isNull);
    },
  );

  test(
    'the fields are sent as the server reads them, and only the chosen service\'s',
    () async {
      final controller = await open();
      controller.optionId.value = 3;
      controller.subjectC.text = 'Rapat direksi';
      controller.descriptionC.text = '20 kursi';
      controller.setField('preferred_schedule', DateTime(2026, 11, 20));
      controller.setField('layout', 'U-Shape');
      controller.setField('attendee_count', 20);

      expect(await controller.submit(), isTrue);

      final sent = verify(
        () => repo.createServiceRequest(
          serviceDefinitionId: 3,
          facilityId: any(named: 'facilityId'),
          subject: 'Rapat direksi',
          description: '20 kursi',
          priority: any(named: 'priority'),
          fields: captureAny(named: 'fields'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).captured.single;
      expect(sent, {
        'preferred_schedule': '2026-11-20',
        'layout': 'U-Shape',
        'attendee_count': 20,
      });
    },
  );

  test('choosing another service starts its form empty', () async {
    final controller = await open();
    controller.optionId.value = 3;
    controller.setField('layout', 'Kelas');

    controller.optionId.value = 4;
    await pumpEventQueue();

    expect(controller.fieldValues, isEmpty);
    expect(controller.fieldPayload(), isNull);
  });

  testWidgets('the chosen service\'s fields are drawn with their labels', (
    tester,
  ) async {
    final controller = (await tester.runAsync(open))!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GamsServiceFields(controller: controller),
          ),
        ),
      ),
    );
    expect(find.text('Layout'), findsNothing);

    controller.optionId.value = 3;
    await tester.pump();

    expect(find.text('Tanggal yang diinginkan'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('Jumlah peserta (opsional)'), findsOneWidget);

    controller.optionId.value = 4;
    await tester.pump();
    expect(find.text('Layout'), findsNothing);
  });
}
