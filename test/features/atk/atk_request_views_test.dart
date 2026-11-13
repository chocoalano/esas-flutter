import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/atk/data/models/atk_models.dart';
import 'package:esas/features/atk/data/repositories/atk_repository.dart';
import 'package:esas/features/atk/presentation/controllers/atk_request_detail_controller.dart';
import 'package:esas/features/atk/presentation/controllers/atk_request_list_controller.dart';
import 'package:esas/features/atk/presentation/views/atk_request_detail_view.dart';
import 'package:esas/features/atk/presentation/views/atk_request_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements AtkRepository {}

const _received = AtkHandover(
  id: 10,
  number: 'ISS-10',
  quantity: 1,
  issuedByName: 'Sari GA',
  issuedAt: '2026-11-12T03:00:00Z',
  receivedAt: '2026-11-12T04:00:00Z',
);

const _pending = AtkHandover(
  id: 11,
  number: 'ISS-11',
  quantity: 2,
  issuedByName: 'Sari GA',
  issuedAt: '2026-11-13T03:00:00Z',
  canAcknowledge: true,
);

AtkRequestDetail _detail({
  List<AtkHandover> issues = const [],
  String status = 'reserved',
  String? reason,
}) => AtkRequestDetail(
  id: 7,
  number: 'IR-0007',
  itemName: 'Kertas A4',
  unit: 'rim',
  locationName: 'Gudang GA',
  quantity: 3,
  status: status,
  statusLabel: atkStatusLabel(status, null),
  reason: reason,
  issuedQuantity: issues.fold(0, (sum, issue) => sum + issue.quantity),
  issues: issues,
);

Future<void> _pump(WidgetTester tester, Widget view) async {
  await tester.pumpWidget(GetMaterialApp(home: view));
  await tester.pumpAndSettle();
}

/// The success snackbar closes on a timer; let it finish before the test does.
Future<void> _drainSnackbar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  final acknowledgeButton = find.widgetWithText(
    FilledButton,
    'Konfirmasi diterima',
  );

  testWidgets(
    'only a handover awaiting confirmation offers "Konfirmasi diterima", and '
    'confirming it asks first, then calls the server',
    (tester) async {
      final repo = _Repo();
      when(
        () => repo.request(7),
      ).thenAnswer((_) async => _detail(issues: const [_received, _pending]));
      when(
        () => repo.acknowledge(
          requestId: 7,
          issueId: 11,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => _detail(
          issues: const [
            _received,
            AtkHandover(
              id: 11,
              number: 'ISS-11',
              quantity: 2,
              issuedByName: 'Sari GA',
              issuedAt: '2026-11-13T03:00:00Z',
              receivedAt: '2026-11-13T04:00:00Z',
            ),
          ],
        ),
      );
      Get.put(AtkRequestDetailController(repository: repo, requestId: 7));

      await _pump(tester, const AtkRequestDetailView());

      expect(find.textContaining('Diserahkan oleh: Sari GA'), findsNWidgets(2));
      expect(find.textContaining('Menunggu konfirmasi Anda'), findsWidgets);
      expect(acknowledgeButton, findsOneWidget);

      await tester.ensureVisible(acknowledgeButton);
      await tester.tap(acknowledgeButton);
      await tester.pumpAndSettle();

      expect(find.text('Pastikan barang sudah Anda terima'), findsOneWidget);
      await tester.tap(find.text('Sudah diterima'));
      await tester.pumpAndSettle();

      verify(
        () => repo.acknowledge(
          requestId: 7,
          issueId: 11,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
      expect(acknowledgeButton, findsNothing);

      await _drainSnackbar(tester);
    },
  );

  testWidgets('cancelling the confirmation sends nothing', (tester) async {
    final repo = _Repo();
    when(
      () => repo.request(7),
    ).thenAnswer((_) async => _detail(issues: const [_pending]));
    Get.put(AtkRequestDetailController(repository: repo, requestId: 7));

    await _pump(tester, const AtkRequestDetailView());
    await tester.ensureVisible(acknowledgeButton);
    await tester.tap(acknowledgeButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    verifyNever(
      () => repo.acknowledge(
        requestId: any(named: 'requestId'),
        issueId: any(named: 'issueId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
  });

  testWidgets(
    'a failed confirmation keeps the handover and says why; the retry reuses '
    'the key after a lost answer',
    (tester) async {
      final repo = _Repo();
      final keys = <String>[];
      when(
        () => repo.request(7),
      ).thenAnswer((_) async => _detail(issues: const [_pending]));
      when(
        () => repo.acknowledge(
          requestId: 7,
          issueId: 11,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        keys.add(invocation.namedArguments[#idempotencyKey] as String);
        throw const ApiException('Server sibuk', status: 503);
      });
      final controller = Get.put(
        AtkRequestDetailController(repository: repo, requestId: 7),
      );

      await _pump(tester, const AtkRequestDetailView());

      expect(await controller.acknowledge(11), isFalse);
      expect(await controller.acknowledge(11), isFalse);
      await tester.pumpAndSettle();

      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      expect(find.textContaining('Konfirmasi belum pasti'), findsOneWidget);
      expect(acknowledgeButton, findsOneWidget);
    },
  );

  testWidgets('a rejected request shows why', (tester) async {
    final repo = _Repo();
    when(() => repo.request(7)).thenAnswer(
      (_) async => _detail(status: 'rejected', reason: 'Stok kosong'),
    );
    Get.put(AtkRequestDetailController(repository: repo, requestId: 7));

    await _pump(tester, const AtkRequestDetailView());

    expect(find.text('Ditolak'), findsOneWidget);
    expect(find.text('Alasan ditolak: Stok kosong'), findsOneWidget);
    expect(acknowledgeButton, findsNothing);
  });

  testWidgets('another employee\'s request reads as not found, no retry', (
    tester,
  ) async {
    final repo = _Repo();
    when(
      () => repo.request(7),
    ).thenThrow(const ApiException('Not found', status: 404));
    Get.put(AtkRequestDetailController(repository: repo, requestId: 7));

    await _pump(tester, const AtkRequestDetailView());

    expect(find.text('Permintaan tidak ditemukan'), findsOneWidget);
    expect(find.text('Coba lagi'), findsNothing);
  });

  group('list', () {
    testWidgets('shows each request and what waits on the employee', (
      tester,
    ) async {
      final repo = _Repo();
      when(() => repo.requests(page: any(named: 'page'))).thenAnswer(
        (_) async => const AtkPage(
          items: [
            AtkRequest(
              id: 7,
              number: 'IR-0007',
              itemName: 'Kertas A4',
              locationName: 'Gudang GA',
              quantity: 3,
              unit: 'rim',
              status: 'reserved',
              statusLabel: 'Direservasi',
              issuedQuantity: 2,
              awaitingReceipt: true,
              createdAt: '2026-11-12T03:00:00Z',
            ),
          ],
        ),
      );
      Get.put(AtkRequestListController(repository: repo));

      await _pump(tester, const AtkRequestListView());

      expect(find.text('IR-0007'), findsOneWidget);
      expect(find.text('Direservasi'), findsOneWidget);
      expect(find.text('Kertas A4 × 3 rim'), findsOneWidget);
      expect(find.text('Diserahkan 2 dari 3 rim'), findsOneWidget);
      expect(find.text('Menunggu konfirmasi Anda'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Permintaan ATK IR-0007.*Direservasi')),
        findsOneWidget,
      );
    });

    testWidgets('no request yet offers to ask for one; a failure retries', (
      tester,
    ) async {
      final repo = _Repo();
      var calls = 0;
      when(() => repo.requests(page: any(named: 'page'))).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw const ApiException('Tidak ada koneksi', code: 'timeout');
        }
        return const AtkPage<AtkRequest>(items: []);
      });
      Get.put(AtkRequestListController(repository: repo));

      await _pump(tester, const AtkRequestListView());
      expect(find.text('Gagal memuat permintaan ATK'), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada permintaan ATK'), findsOneWidget);
      // The empty state's action and the FAB both ask for ATK.
      expect(find.text('Minta ATK'), findsNWidgets(2));
    });

    testWidgets('loads the next page when asked', (tester) async {
      final repo = _Repo();
      AtkRequest row(int id) => AtkRequest(
        id: id,
        number: 'IR-$id',
        itemName: 'Pulpen',
        locationName: 'Gudang GA',
        quantity: 1,
        unit: 'pcs',
        status: 'requested',
        statusLabel: 'Diajukan',
      );
      when(() => repo.requests()).thenAnswer(
        (_) async => AtkPage(items: [row(1)], currentPage: 1, lastPage: 2),
      );
      when(() => repo.requests(page: 2)).thenAnswer(
        (_) async => AtkPage(items: [row(2)], currentPage: 2, lastPage: 2),
      );
      Get.put(AtkRequestListController(repository: repo));

      await _pump(tester, const AtkRequestListView());
      await tester.tap(find.text('Muat lebih banyak'));
      await tester.pumpAndSettle();

      expect(find.text('IR-1'), findsOneWidget);
      expect(find.text('IR-2'), findsOneWidget);
      expect(find.text('Muat lebih banyak'), findsNothing);
    });
  });
}
