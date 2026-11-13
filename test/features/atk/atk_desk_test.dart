import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/atk/data/models/atk_models.dart';
import 'package:esas/features/atk/data/repositories/atk_repository.dart';
import 'package:esas/features/atk/presentation/controllers/atk_desk_detail_controller.dart';
import 'package:esas/features/atk/presentation/controllers/atk_desk_list_controller.dart';
import 'package:esas/features/atk/presentation/controllers/atk_request_create_controller.dart';
import 'package:esas/features/atk/presentation/controllers/atk_request_detail_controller.dart';
import 'package:esas/features/atk/presentation/controllers/atk_request_list_controller.dart';
import 'package:esas/features/atk/presentation/views/atk_desk_detail_view.dart';
import 'package:esas/features/atk/presentation/views/atk_desk_list_view.dart';
import 'package:esas/features/atk/presentation/views/atk_request_create_view.dart';
import 'package:esas/features/atk/presentation/views/atk_request_detail_view.dart';
import 'package:esas/features/atk/presentation/views/atk_request_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements AtkRepository {}

AtkDeskDetail _detail({
  List<String> allowed = const ['reserve', 'reject'],
  String status = 'requested',
  int lockVersion = 2,
  int issued = 0,
  String itemName = 'Kertas A4',
  String requester = 'Budi Santoso',
}) => AtkDeskDetail(
  request: AtkDeskRequest(
    id: 8,
    number: 'IR-0008',
    itemName: itemName,
    itemCode: 'ATK-A4',
    unit: 'rim',
    locationName: 'Gudang GA Lantai 1',
    quantity: 5,
    status: status,
    statusLabel: atkStatusLabel(status, null),
    lockVersion: lockVersion,
    createdAt: '2026-11-12T03:00:00Z',
    requesterName: requester,
    allowedActions: allowed,
  ),
  issuedQuantity: issued,
  stock: const AtkStock(onHand: 30, reserved: 5, available: 25),
  movements: const [
    AtkMovement(command: 'reserve', quantity: 5, at: '2026-11-12T04:00:00Z'),
  ],
);

Future<void> _pump(WidgetTester tester, Widget view) async {
  await tester.pumpWidget(GetMaterialApp(home: view));
  await tester.pumpAndSettle();
}

/// A Material button (filled, outlined or text) labelled [label].
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    return initializeDateFormatting('id_ID');
  });
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  group('desk list', () {
    testWidgets('a non-officer is told they have no access, with no retry', (
      tester,
    ) async {
      final repo = _Repo();
      when(() => repo.desk(page: any(named: 'page'))).thenThrow(
        const ApiException(
          'Tidak diizinkan',
          status: 403,
          code: 'DESK_NOT_ALLOWED',
        ),
      );
      Get.put(AtkDeskListController(repository: repo));

      await _pump(tester, const AtkDeskListView());

      expect(
        find.text('Anda tidak memiliki akses ke meja ATK'),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsNothing);
      expect(find.text('Tidak diizinkan'), findsNothing);
    });

    testWidgets('open requests show who asked and what needs action', (
      tester,
    ) async {
      final repo = _Repo();
      when(() => repo.desk(page: any(named: 'page'))).thenAnswer(
        (_) async => AtkPage(
          items: [
            _detail().request,
            AtkDeskRequest(
              id: 9,
              number: 'IR-0009',
              itemName: 'Pulpen',
              unit: 'pcs',
              locationName: 'Gudang GA',
              quantity: 2,
              status: 'reserved',
              statusLabel: 'Direservasi',
              requesterName: 'Ani',
            ),
          ],
        ),
      );
      Get.put(AtkDeskListController(repository: repo));

      await _pump(tester, const AtkDeskListView());

      expect(find.text('Kertas A4 × 5 rim'), findsOneWidget);
      expect(find.text('Pemohon: Budi Santoso'), findsOneWidget);
      expect(find.text('Pulpen × 2 pcs'), findsOneWidget);
      // Only the first has allowed actions.
      expect(find.text('Perlu tindakan'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('IR-0008.*perlu tindakan')),
        findsOneWidget,
      );
    });
  });

  group('desk detail', () {
    testWidgets('shows stock and only the actions the server allows', (
      tester,
    ) async {
      final repo = _Repo();
      when(() => repo.deskRequest(8)).thenAnswer((_) async => _detail());
      Get.put(AtkDeskDetailController(repository: repo, requestId: 8));

      await _pump(tester, const AtkDeskDetailView());

      expect(_button('Reservasi'), findsOneWidget);
      expect(_button('Tolak'), findsOneWidget);
      expect(_button('Serahkan'), findsNothing);
      expect(find.text('25 rim'), findsOneWidget);
      expect(find.text('Tersedia'), findsOneWidget);
      expect(find.text('Dipesan'), findsOneWidget);
    });

    testWidgets('a reserved request may only be handed over', (tester) async {
      final repo = _Repo();
      when(() => repo.deskRequest(8)).thenAnswer(
        (_) async =>
            _detail(allowed: const ['issue'], status: 'reserved', issued: 2),
      );
      when(
        () => repo.deskAct(
          8,
          'issue',
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => _detail(allowed: const [], status: 'reserved', issued: 5),
      );
      Get.put(AtkDeskDetailController(repository: repo, requestId: 8));

      await _pump(tester, const AtkDeskDetailView());

      expect(_button('Reservasi'), findsNothing);
      expect(_button('Tolak'), findsNothing);
      await tester.tap(_button('Serahkan'));
      await tester.pumpAndSettle();

      // Defaults to what is still owed, and never more.
      expect(find.widgetWithText(TextField, '3'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '4');
      await tester.tap(_button('Serahkan barang'));
      await tester.pumpAndSettle();
      expect(find.text('Paling banyak 3 rim.'), findsOneWidget);
      verifyNever(
        () => repo.deskAct(
          any(),
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );

      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(_button('Serahkan barang'));
      await tester.pumpAndSettle();

      final body =
          verify(
                () => repo.deskAct(
                  8,
                  'issue',
                  captureAny(),
                  idempotencyKey: any(named: 'idempotencyKey'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body, {'quantity': 3});
      expect(find.byType(AlertDialog), findsNothing);
      expect(_button('Serahkan'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'the reject dialog keeps the reason when the server refuses, and sends '
      'the lock_version',
      (tester) async {
        final repo = _Repo();
        when(() => repo.deskRequest(8)).thenAnswer((_) async => _detail());
        when(
          () => repo.deskAct(
            8,
            'reject',
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenThrow(const ApiException('Alasan terlalu singkat.', status: 422));
        Get.put(AtkDeskDetailController(repository: repo, requestId: 8));

        await _pump(tester, const AtkDeskDetailView());

        await tester.tap(_button('Tolak'));
        await tester.pumpAndSettle();

        // A reason is required before anything is sent.
        await tester.tap(_button('Tolak permintaan'));
        await tester.pumpAndSettle();
        expect(find.text('Alasan penolakan wajib diisi.'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Stok bulan ini habis');
        await tester.tap(_button('Tolak permintaan'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'Stok bulan ini habis'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Alasan terlalu singkat.'),
          ),
          findsOneWidget,
        );

        final body =
            verify(
                  () => repo.deskAct(
                    8,
                    'reject',
                    captureAny(),
                    idempotencyKey: any(named: 'idempotencyKey'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(body, {'reason': 'Stok bulan ini habis', 'lock_version': 2});
      },
    );

    testWidgets('a stale screen is told the data changed and reloads', (
      tester,
    ) async {
      final repo = _Repo();
      var loads = 0;
      when(() => repo.deskRequest(8)).thenAnswer((_) async {
        loads++;
        return loads == 1
            ? _detail()
            : _detail(allowed: const ['issue'], status: 'reserved');
      });
      when(
        () => repo.deskAct(
          8,
          'reserve',
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const ApiException(
          'Versi kedaluwarsa',
          status: 409,
          code: 'STALE_VERSION',
        ),
      );
      Get.put(AtkDeskDetailController(repository: repo, requestId: 8));

      await _pump(tester, const AtkDeskDetailView());
      await tester.tap(_button('Reservasi'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Reservasi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(loads, 2);
      expect(find.text('Data berubah, dimuat ulang.'), findsOneWidget);
      expect(_button('Reservasi'), findsNothing);
      expect(_button('Serahkan'), findsOneWidget);
    });

    testWidgets('a non-officer opening a request is told they have no access', (
      tester,
    ) async {
      final repo = _Repo();
      when(() => repo.deskRequest(8)).thenThrow(
        const ApiException('no', status: 403, code: 'DESK_NOT_ALLOWED'),
      );
      Get.put(AtkDeskDetailController(repository: repo, requestId: 8));

      await _pump(tester, const AtkDeskDetailView());

      expect(
        find.text('Anda tidak memiliki akses ke meja ATK'),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsNothing);
    });
  });

  testWidgets('on a 320dp phone at double text size no ATK screen overflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Future<void> pumpScaled(Widget view) async {
      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: view,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Lay out what sits below the fold too.
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -4000),
        4000,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    final repo = _Repo();
    when(() => repo.deskRequest(8)).thenAnswer(
      (_) async => _detail(
        itemName: 'Kertas HVS A4 80 gram putih untuk printer laser kantor',
        requester: 'Raden Ajeng Kusumawardhani Prameswari Wijayakusuma',
      ),
    );
    when(() => repo.requests(page: any(named: 'page'))).thenAnswer(
      (_) async => const AtkPage(
        items: [
          AtkRequest(
            id: 7,
            number: 'IR-2026-000000007',
            itemName: 'Map plastik transparan dengan kancing ukuran folio',
            locationName: 'Gudang GA Gedung Kantor Pusat Lantai Dasar',
            quantity: 120,
            unit: 'lembar',
            status: 'reserved',
            statusLabel: 'Direservasi',
            issuedQuantity: 60,
            awaitingReceipt: true,
            createdAt: '2026-11-12T03:00:00Z',
          ),
        ],
      ),
    );
    Get.put(AtkDeskDetailController(repository: repo, requestId: 8));
    Get.put(AtkRequestListController(repository: repo));

    await pumpScaled(const AtkDeskDetailView());
    expect(_button('Reservasi'), findsOneWidget);

    await pumpScaled(const AtkRequestListView());
    expect(find.text('IR-2026-000000007'), findsOneWidget);

    when(() => repo.request(7)).thenAnswer(
      (_) async => const AtkRequestDetail(
        id: 7,
        number: 'IR-2026-000000007',
        itemName: 'Map plastik transparan dengan kancing ukuran folio',
        unit: 'lembar',
        locationName: 'Gudang GA Gedung Kantor Pusat Lantai Dasar',
        quantity: 120,
        status: 'reserved',
        statusLabel: 'Direservasi',
        issuedQuantity: 60,
        issues: [
          AtkHandover(
            id: 1,
            number: 'ISS-2026-000000001',
            quantity: 60,
            issuedByName: 'Raden Ajeng Kusumawardhani Prameswari',
            issuedAt: '2026-11-12T03:00:00Z',
            canAcknowledge: true,
          ),
        ],
      ),
    );
    Get.put(AtkRequestDetailController(repository: repo, requestId: 7));
    await pumpScaled(const AtkRequestDetailView());
    expect(find.text('Konfirmasi diterima'), findsOneWidget);

    when(() => repo.items()).thenAnswer(
      (_) async => const [
        AtkItem(id: 1, name: 'Kertas HVS A4 80 gram putih', unit: 'rim'),
      ],
    );
    when(() => repo.locations()).thenAnswer(
      (_) async => const [
        AtkLocation(id: 1, name: 'Gudang GA Gedung Kantor Pusat Lantai Dasar'),
      ],
    );
    Get.put(AtkRequestCreateController(repository: repo));
    await pumpScaled(const AtkRequestCreateView());
    expect(find.text('Kirim permintaan'), findsOneWidget);
  });
}
