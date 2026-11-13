import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/mtms/data/mtms_reports.dart';
import 'package:esas/features/mtms/presentation/controllers/mtms_report_controllers.dart';
import 'package:esas/features/mtms/presentation/views/mtms_report_views.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements MtmsReportsRepository {}

/// FUNC-D02. An employee had no way to report broken equipment from the
/// phone, or to see what came of a report.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _Repo repo;

  final linked = MtmsReport.fromJson({
    'id': 5,
    'request_number': 'MR-0005',
    'symptom': 'Kompresor bocor oli',
    'status': 'wo_linked',
    'status_label': 'Sedang ditangani',
    'equipment_name': 'Kompresor',
    'equipment_tag': 'CMP-01',
    'work_order': {
      'number': 'WO-0042',
      'status': 'in_progress',
      'status_label': 'Dikerjakan',
    },
    'created_at': '2026-11-11T02:00:00Z',
  });

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
  });

  tearDown(Get.reset);

  test('a report names the work it led to', () {
    expect(linked.workOrderNumber, 'WO-0042');
    expect(linked.workOrderStatusLabel, 'Dikerjakan');
    expect(linked.statusLabel, 'Sedang ditangani');
  });

  group('filing', () {
    late MtmsReportCreateController controller;
    final keys = <String>[];

    setUp(() async {
      keys.clear();
      when(() => repo.equipment()).thenAnswer(
        (_) async => const [
          MtmsEquipment(id: 7, name: 'Kompresor', tag: 'CMP-01'),
        ],
      );
      controller = MtmsReportCreateController(repository: repo);
      controller.onInit();
      await pumpEventQueue();
    });

    void answer(Future<({int id, String number})> Function() reply) {
      when(
        () => repo.file(
          equipmentId: any(named: 'equipmentId'),
          symptom: any(named: 'symptom'),
          severity: any(named: 'severity'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) {
        keys.add(invocation.namedArguments[#idempotencyKey] as String);
        return reply();
      });
    }

    test('needs equipment and a symptom', () {
      expect(controller.validate(), 'Pilih peralatan yang rusak.');
      controller.equipmentId.value = 7;
      expect(controller.validate(), 'Tuliskan gejala kerusakannya.');
      controller.symptomC.text = 'Bocor oli';
      expect(controller.validate(), isNull);
    });

    test(
      'a lost answer keeps the key, so the retry cannot file twice',
      () async {
        controller.equipmentId.value = 7;
        controller.symptomC.text = 'Bocor oli';

        answer(
          () async => throw const ApiException('Server sibuk', status: 503),
        );
        expect(await controller.submit(), isNull);

        answer(() async => (id: 5, number: 'MR-0005'));
        expect(await controller.submit(), 'MR-0005');

        expect(keys, hasLength(2));
        expect(keys.first, keys.last);
      },
    );

    test('a definite refusal ends the attempt; the next one is new', () async {
      controller.equipmentId.value = 7;
      controller.symptomC.text = 'Bocor oli';

      answer(
        () async =>
            throw const ApiException('Peralatan tidak aktif', status: 422),
      );
      expect(await controller.submit(), isNull);
      expect(controller.error.value, 'Peralatan tidak aktif');

      answer(() async => (id: 6, number: 'MR-0006'));
      expect(await controller.submit(), 'MR-0006');
      expect(keys.first, isNot(keys.last));
    });
  });

  testWidgets('the list shows each report and the work order it became', (
    tester,
  ) async {
    when(
      () => repo.reports(page: any(named: 'page')),
    ).thenAnswer((_) async => (reports: [linked], lastPage: 1));
    Get.put(MtmsReportListController(repository: repo));

    await tester.pumpWidget(const GetMaterialApp(home: MtmsReportListView()));
    await tester.pumpAndSettle();

    expect(find.text('MR-0005'), findsOneWidget);
    expect(find.text('Sedang ditangani'), findsOneWidget);
    expect(find.text('Perintah kerja WO-0042 • Dikerjakan'), findsOneWidget);
  });

  testWidgets('no report yet offers to file one', (tester) async {
    when(
      () => repo.reports(page: any(named: 'page')),
    ).thenAnswer((_) async => (reports: <MtmsReport>[], lastPage: 1));
    Get.put(MtmsReportListController(repository: repo));

    await tester.pumpWidget(const GetMaterialApp(home: MtmsReportListView()));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada laporan'), findsOneWidget);
  });
}
