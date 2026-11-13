import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/gams/data/models/gams_service_request.dart';
import 'package:esas/features/gams/data/repositories/gams_repository.dart';
import 'package:esas/features/gams/presentation/controllers/gams_request_tracking_controllers.dart';
import 'package:esas/features/gams/presentation/views/gams_request_tracking_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements GamsRepository {}

/// FUNC-D05. The GA dashboard showed three read-only rows per section: an
/// older request could not be found, and none could be opened.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _Repo repo;

  final listed = GamsServiceRequest.fromJson({
    'id': 21,
    'number': 'SR-00000021',
    'subject': 'Penataan ruang rapat',
    'status': 'triaged',
    'status_label': 'Sudah Diperiksa Tim GA',
    'service_definition': 'Penataan ruang',
    'created_at': '2026-11-10T02:00:00Z',
  });
  final detail = GamsServiceRequest.fromJson({
    'id': 22,
    'number': 'SR-00000022',
    'subject': 'AC ruang rapat bocor',
    'description': 'Menetes ke meja',
    'priority': 'high',
    'status': 'resolved',
    'status_label': 'Selesai',
    'resolution_note': 'Selang pembuangan diganti',
    'service_definition': {'id': 3, 'title': 'Perbaikan AC', 'code': 'AC'},
    'facility': {'id': 9, 'name': 'Gedung A', 'code': 'A'},
    'field_data': {
      'fields': {'preferred_schedule': '2026-11-12', 'needs_ladder': true},
    },
    'submitted_at': '2026-11-09T02:00:00Z',
    'triaged_at': '2026-11-09T03:00:00Z',
    'resolved_at': '2026-11-10T08:00:00Z',
  });

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
  });

  tearDown(Get.reset);

  test('the detail\'s objects and the server\'s own status words are read', () {
    expect(listed.statusLabel, 'Sudah Diperiksa Tim GA');
    expect(detail.serviceDefinition, 'Perbaikan AC');
    expect(detail.facility, 'Gedung A');
    expect(detail.answers['needs_ladder'], isTrue);
  });

  testWidgets('every request is listed, not three', (tester) async {
    when(
      () => repo.serviceRequests(page: any(named: 'page')),
    ).thenAnswer((_) async => [listed, detail]);
    Get.put(GamsRequestListController(repository: repo));

    await tester.pumpWidget(const GetMaterialApp(home: GamsRequestListView()));
    await tester.pumpAndSettle();

    expect(find.text('Penataan ruang rapat'), findsOneWidget);
    expect(find.text('AC ruang rapat bocor'), findsOneWidget);
  });

  testWidgets(
    'a request shows the answers given, the outcome and its history',
    (tester) async {
      when(() => repo.serviceRequest(22)).thenAnswer((_) async => detail);
      Get.put(GamsRequestDetailController(repository: repo, requestId: 22));

      await tester.pumpWidget(
        const GetMaterialApp(home: GamsRequestDetailView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Layanan: Perbaikan AC'), findsOneWidget);
      expect(find.text('Needs Ladder: Ya'), findsOneWidget);
      expect(find.text('Selang pembuangan diganti'), findsOneWidget);
      expect(find.textContaining('Diperiksa tim GA'), findsOneWidget);
      expect(find.textContaining('Dibatalkan'), findsNothing);
    },
  );

  testWidgets('somebody else\'s request reads as not found', (tester) async {
    when(
      () => repo.serviceRequest(99),
    ).thenThrow(const ApiException('Tidak ditemukan', status: 404));
    Get.put(GamsRequestDetailController(repository: repo, requestId: 99));

    await tester.pumpWidget(
      const GetMaterialApp(home: GamsRequestDetailView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permintaan tidak ditemukan'), findsOneWidget);
  });

  group('withdrawing a request (D-06)', () {
    final cancellable = GamsServiceRequest.fromJson({
      'id': 31,
      'number': 'SR-00000031',
      'subject': 'Lampu koridor mati',
      'status': 'submitted',
      'status_label': 'Diajukan',
      'can_cancel': true,
    });
    final started = GamsServiceRequest.fromJson({
      'id': 32,
      'number': 'SR-00000032',
      'subject': 'AC bocor',
      'status': 'in_progress',
      'status_label': 'Sedang dikerjakan',
      'can_cancel': false,
    });

    testWidgets('no cancel once work started', (tester) async {
      when(() => repo.serviceRequest(32)).thenAnswer((_) async => started);
      Get.put(GamsRequestDetailController(repository: repo, requestId: 32));
      await tester.pumpWidget(
        const GetMaterialApp(home: GamsRequestDetailView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batalkan permintaan'), findsNothing);
    });

    testWidgets(
      'a failed cancel keeps the dialog and the reason; the retry reuses the key',
      (tester) async {
        final keys = <String?>[];
        var fail = true;
        when(
          () => repo.serviceRequest(31),
        ).thenAnswer((_) async => cancellable);
        when(
          () => repo.cancelServiceRequest(
            31,
            reason: any(named: 'reason'),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((invocation) async {
          keys.add(invocation.namedArguments[#idempotencyKey] as String?);
          if (fail) {
            throw const ApiException('Server sibuk', status: 503);
          }
        });
        Get.put(GamsRequestDetailController(repository: repo, requestId: 31));
        await tester.pumpWidget(
          const GetMaterialApp(home: GamsRequestDetailView()),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Batalkan permintaan'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('tidak dapat dibuka kembali'),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField), 'Sudah diperbaiki');
        await tester.tap(find.text('Batalkan'));
        await tester.pumpAndSettle();

        expect(find.text('Server sibuk'), findsOneWidget);
        expect(find.text('Sudah diperbaiki'), findsOneWidget);

        fail = false;
        await tester.tap(find.text('Batalkan'));
        await tester.pumpAndSettle();

        expect(find.text('Batalkan permintaan?'), findsNothing);
        expect(keys, hasLength(2));
        expect(keys.first, keys.last);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );
  });
}
