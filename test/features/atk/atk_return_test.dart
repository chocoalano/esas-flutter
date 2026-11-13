import 'package:esas/core/network/api_client.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/network/idempotency_key.dart';
import 'package:esas/features/atk/data/models/atk_models.dart';
import 'package:esas/features/atk/data/repositories/atk_repository.dart';
import 'package:esas/features/atk/presentation/controllers/atk_desk_detail_controller.dart';
import 'package:esas/features/atk/presentation/controllers/atk_request_detail_controller.dart';
import 'package:esas/features/atk/presentation/views/atk_desk_detail_view.dart';
import 'package:esas/features/atk/presentation/views/atk_request_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements AtkRepository {}

class _Client extends Mock implements ApiClient {}

typedef _Recorded = ({AtkDeskDetail detail, String message});

const _serverMessage = 'Pengembalian barang dicatat.';

/// Received in full; up to [returnable] may come back.
AtkHandover _returnable({int returnable = 3, int returned = 0}) => AtkHandover(
  id: 1,
  number: 'ISS-1',
  quantity: 3,
  issuedByName: 'Sari GA',
  issuedAt: '2026-11-12T03:00:00Z',
  receivedByName: 'Budi Santoso',
  receivedAt: '2026-11-12T04:00:00Z',
  returnedQuantity: returned,
  returnableQuantity: returnable,
  canReturn: returnable > 0,
);

/// Handed over but not confirmed yet: the server does not allow a return.
const _unconfirmed = AtkHandover(
  id: 2,
  number: 'ISS-2',
  quantity: 2,
  issuedByName: 'Sari GA',
  issuedAt: '2026-11-12T05:00:00Z',
  returnableQuantity: 2,
);

AtkReturn _returnRow({int id = 5, int quantity = 2, String reason = 'Rusak'}) =>
    AtkReturn(
      id: id,
      number: 'RTN-000$id',
      issueId: 1,
      quantity: quantity,
      reason: reason,
      returnedByName: 'Sari GA',
      returnedAt: '2026-11-13T02:00:00Z',
    );

AtkDeskDetail _detail({
  List<AtkHandover>? issues,
  List<AtkReturn> returns = const [],
}) => AtkDeskDetail(
  request: const AtkDeskRequest(
    id: 8,
    number: 'IR-0008',
    itemName: 'Kertas A4',
    unit: 'rim',
    locationName: 'Gudang GA',
    quantity: 5,
    status: 'reserved',
    statusLabel: 'Direservasi',
    lockVersion: 4,
    requesterName: 'Budi Santoso',
  ),
  issuedQuantity: 5,
  issues: issues ?? [_returnable(), _unconfirmed],
  returnedQuantity: returns.fold(0, (sum, row) => sum + row.quantity),
  returns: returns,
);

/// A Material button (filled, outlined or text) labelled [label].
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

Finder _inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

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

  group('repository', () {
    late _Client client;
    late AtkRepository repository;

    setUp(() {
      client = _Client();
      repository = AtkRepository(client);
    });

    test('posts quantity and reason to the handover with the key, and reads '
        'the request back with the server\'s sentence', () async {
      when(
        () => client.postObject(any(), any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => {
          'message': _serverMessage,
          'data': {
            'id': 8,
            'number': 'IR-0008',
            'status': 'reserved',
            'returned_quantity': 2,
            'returns': [
              {
                'id': 5,
                'number': 'RTN-0005',
                'issue_id': 1,
                'quantity': 2,
                'reason': 'Rusak',
              },
            ],
          },
        },
      );

      final recorded = await repository.returnItems(
        requestId: 8,
        issueId: 1,
        quantity: 2,
        reason: 'Rusak',
        idempotencyKey: 'key-1',
      );

      final call = verify(
        () => client.postObject(
          captureAny(),
          captureAny(),
          headers: captureAny(named: 'headers'),
        ),
      ).captured;
      expect(call[0], '/gams/inventory-desk/8/issues/1/return');
      expect(call[1], {'quantity': 2, 'reason': 'Rusak'});
      expect(call[2], {IdempotencyKey.header: 'key-1'});
      expect(recorded.message, _serverMessage);
      expect(recorded.detail.returnedQuantity, 2);
      expect(recorded.detail.returns.single.number, 'RTN-0005');
    });

    test('a reply without a sentence still says it was recorded', () async {
      when(
        () => client.postObject(any(), any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => {'data': <String, dynamic>{}});

      final recorded = await repository.returnItems(
        requestId: 8,
        issueId: 1,
        quantity: 1,
        reason: 'Rusak',
        idempotencyKey: 'key-2',
      );

      expect(recorded.message, _serverMessage);
    });
  });

  group('controller', () {
    late _Repo repo;
    late AtkDeskDetailController controller;
    late List<String> keys;
    late int loads;

    setUp(() async {
      repo = _Repo();
      keys = [];
      loads = 0;
      when(() => repo.deskRequest(8)).thenAnswer((_) async {
        loads++;
        return _detail();
      });
      controller = AtkDeskDetailController(repository: repo, requestId: 8);
      await controller.load();
    });

    void answer(Future<_Recorded> Function() reply) {
      when(
        () => repo.returnItems(
          requestId: any(named: 'requestId'),
          issueId: any(named: 'issueId'),
          quantity: any(named: 'quantity'),
          reason: any(named: 'reason'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) {
        keys.add(invocation.namedArguments[#idempotencyKey] as String);
        return reply();
      });
    }

    Future<_Recorded> recorded() async => (
      detail: _detail(
        issues: [_returnable(returnable: 2, returned: 1), _unconfirmed],
        returns: [_returnRow(quantity: 1)],
      ),
      message: _serverMessage,
    );

    test('sends the handover, quantity and trimmed reason with a key, and '
        'shows the request the server answers', () async {
      answer(recorded);

      final message = await controller.returnItems(
        1,
        quantity: 1,
        reason: '  Rusak  ',
      );

      expect(message, _serverMessage);
      verify(
        () => repo.returnItems(
          requestId: 8,
          issueId: 1,
          quantity: 1,
          reason: 'Rusak',
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
      expect(keys.single, isNotEmpty);
      expect(controller.detail.value!.returns, hasLength(1));
      expect(controller.notice.value, isNull);
    });

    test('a lost answer keeps the key for the retry; after success the next '
        'return is a new intent with a new key', () async {
      answer(() async => throw const ApiException('Server sibuk', status: 503));
      expect(
        await controller.returnItems(1, quantity: 1, reason: 'Rusak'),
        isNull,
      );
      expect(controller.notice.value, contains('tidak akan mencatatnya'));
      expect(loads, 2, reason: 'an uncertain answer reads the request back');

      answer(() async => throw const ApiException('offline', code: 'timeout'));
      expect(
        await controller.returnItems(1, quantity: 1, reason: 'Rusak'),
        isNull,
      );

      answer(recorded);
      expect(
        await controller.returnItems(1, quantity: 1, reason: 'Rusak'),
        _serverMessage,
      );
      expect(
        await controller.returnItems(1, quantity: 1, reason: 'Rusak'),
        _serverMessage,
      );

      expect(keys, hasLength(4));
      expect(keys.take(3).toSet(), hasLength(1));
      expect(keys.last, isNot(keys.first));
    });

    test('a definite refusal drops the key; the next attempt is new', () async {
      answer(
        () async => throw const ApiException(
          'Data tidak valid.',
          status: 422,
          errors: {'reason': 'Alasan wajib diisi.'},
        ),
      );
      expect(
        await controller.returnItems(1, quantity: 1, reason: 'Rusak'),
        isNull,
      );
      expect(controller.notice.value, 'Alasan wajib diisi.');

      answer(recorded);
      expect(
        await controller.returnItems(1, quantity: 1, reason: 'Rusak'),
        _serverMessage,
      );

      expect(keys, hasLength(2));
      expect(keys.first, isNot(keys.last));
    });

    test('more than is still returnable is explained and the request is '
        'read back', () async {
      answer(
        () async => throw const ApiException(
          'Jumlah melebihi.',
          status: 422,
          code: 'EXCEEDS_ISSUED_QUANTITY',
        ),
      );

      expect(
        await controller.returnItems(1, quantity: 3, reason: 'Rusak'),
        isNull,
      );

      expect(
        controller.notice.value,
        'Jumlah melebihi barang yang masih bisa dikembalikan.',
      );
      expect(loads, 2);
    });

    test('no permission is said plainly; the screen stays', () async {
      answer(
        () async => throw const ApiException(
          'Forbidden',
          status: 403,
          code: 'PERMISSION_DENIED',
        ),
      );

      expect(
        await controller.returnItems(1, quantity: 1, reason: 'Rusak'),
        isNull,
      );

      expect(
        controller.notice.value,
        'Anda tidak berhak melakukan tindakan ini.',
      );
      expect(controller.error.value, isNull);
    });

    test('a handover not on this request is a notice, not a missing '
        'request', () async {
      answer(() async => throw const ApiException('Not found', status: 404));

      expect(
        await controller.returnItems(1, quantity: 1, reason: 'Rusak'),
        isNull,
      );

      expect(
        controller.notice.value,
        'Penyerahan ini tidak ditemukan pada permintaan ini.',
      );
      expect(controller.error.value, isNull);
      expect(controller.detail.value, isNotNull);
    });

    test('nothing is sent without a reason or outside 1..returnable', () async {
      answer(recorded);

      expect(
        await controller.returnItems(1, quantity: 1, reason: '   '),
        isNull,
      );
      expect(controller.notice.value, 'Alasan pengembalian wajib diisi.');
      expect(
        await controller.returnItems(1, quantity: 0, reason: 'Rusak'),
        isNull,
      );
      expect(controller.notice.value, 'Jumlah minimal 1.');
      expect(
        await controller.returnItems(1, quantity: 4, reason: 'Rusak'),
        isNull,
      );
      expect(controller.notice.value, 'Paling banyak 3 rim.');
      // The server does not allow a return of the unconfirmed handover.
      expect(
        await controller.returnItems(2, quantity: 1, reason: 'Rusak'),
        isNull,
      );

      expect(keys, isEmpty);
    });

    test('a second tap while the first is on its way sends nothing', () async {
      answer(recorded);

      final first = controller.returnItems(1, quantity: 1, reason: 'Rusak');
      final second = controller.returnItems(1, quantity: 1, reason: 'Rusak');

      expect(await second, isNull);
      expect(await first, _serverMessage);
      expect(keys, hasLength(1));
    });
  });

  group('desk detail', () {
    testWidgets('"Terima Pengembalian" is offered only where the server allows '
        'it, and what came back shows on the handover', (tester) async {
      final repo = _Repo();
      when(() => repo.deskRequest(8)).thenAnswer(
        (_) async => _detail(
          issues: [
            _returnable(returnable: 1, returned: 2),
            _unconfirmed,
            const AtkHandover(
              id: 3,
              number: 'ISS-3',
              quantity: 1,
              returnedQuantity: 1,
              canReturn: true,
            ),
          ],
        ),
      );
      Get.put(AtkDeskDetailController(repository: repo, requestId: 8));

      await _pump(tester, const AtkDeskDetailView());
      await tester.scrollUntilVisible(
        find.text('Riwayat pergerakan stok'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // ISS-1 only: ISS-2 is not allowed, ISS-3 has nothing left.
      expect(_button('Terima Pengembalian'), findsOneWidget);
      expect(find.text('Dikembalikan: 2 rim'), findsOneWidget);
      expect(find.text('Dikembalikan: 1 rim'), findsOneWidget);
      // No return recorded yet: no history section.
      expect(find.text('Riwayat Pengembalian'), findsNothing);
    });

    testWidgets('the dialog defaults to all that may come back, checks the '
        'quantity and the reason, and on success closes and shows the '
        'history', (tester) async {
      final repo = _Repo();
      final keys = <String>[];
      when(() => repo.deskRequest(8)).thenAnswer((_) async => _detail());
      when(
        () => repo.returnItems(
          requestId: 8,
          issueId: 1,
          quantity: any(named: 'quantity'),
          reason: any(named: 'reason'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        keys.add(invocation.namedArguments[#idempotencyKey] as String);
        return (
          detail: _detail(
            issues: [_returnable(returnable: 1, returned: 2), _unconfirmed],
            returns: [_returnRow(quantity: 2, reason: 'Kemasan sobek')],
          ),
          message: _serverMessage,
        );
      });
      Get.put(AtkDeskDetailController(repository: repo, requestId: 8));

      await _pump(tester, const AtkDeskDetailView());
      await tester.ensureVisible(_button('Terima Pengembalian'));
      await tester.tap(_button('Terima Pengembalian'));
      await tester.pumpAndSettle();

      final quantity = _inDialog(
        find.widgetWithText(TextField, 'Jumlah dikembalikan'),
      );
      final reason = _inDialog(
        find.widgetWithText(TextField, 'Alasan pengembalian'),
      );
      expect(find.textContaining('Penyerahan ISS-1'), findsOneWidget);
      expect(
        tester.widget<TextField>(quantity).controller!.text,
        '3',
        reason: 'defaults to the returnable quantity',
      );

      // The stepper stops at the bound.
      final plus = _inDialog(
        find.widgetWithIcon(IconButton, Icons.add_rounded),
      );
      expect(tester.widget<IconButton>(plus).onPressed, isNull);
      await tester.tap(_inDialog(find.byTooltip('Kurangi')));
      await tester.pump();
      expect(tester.widget<TextField>(quantity).controller!.text, '2');

      // No reason: refused before anything is sent.
      await tester.tap(_button('Catat pengembalian'));
      await tester.pumpAndSettle();
      expect(find.text('Alasan pengembalian wajib diisi.'), findsOneWidget);

      // Over the bound, and under it.
      await tester.enterText(reason, 'Kemasan sobek');
      await tester.enterText(quantity, '4');
      await tester.tap(_button('Catat pengembalian'));
      await tester.pumpAndSettle();
      expect(find.text('Paling banyak 3 rim.'), findsOneWidget);
      await tester.enterText(quantity, '0');
      await tester.tap(_button('Catat pengembalian'));
      await tester.pumpAndSettle();
      expect(find.text('Jumlah minimal 1.'), findsOneWidget);
      expect(keys, isEmpty);

      await tester.enterText(quantity, '2');
      await tester.tap(_button('Catat pengembalian'));
      await tester.pumpAndSettle();

      verify(
        () => repo.returnItems(
          requestId: 8,
          issueId: 1,
          quantity: 2,
          reason: 'Kemasan sobek',
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
      expect(keys.single, isNotEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(_serverMessage), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Riwayat Pengembalian'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Alasan: Kemasan sobek'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('RTN-0005 • 2 rim'), findsOneWidget);
      expect(find.text('Dicatat oleh: Sari GA'), findsOneWidget);
      expect(find.text('Dari penyerahan: ISS-1'), findsOneWidget);
      expect(find.textContaining('Waktu pengembalian: 13 Nov 2026'), findsOne);

      await _drainSnackbar(tester);
    });

    testWidgets('more than is still returnable keeps the dialog open, says so, '
        'and shows what is left now', (tester) async {
      final repo = _Repo();
      var loads = 0;
      when(() => repo.deskRequest(8)).thenAnswer((_) async {
        loads++;
        return loads == 1
            ? _detail()
            : _detail(
                issues: [_returnable(returnable: 1, returned: 2), _unconfirmed],
                returns: [_returnRow()],
              );
      });
      when(
        () => repo.returnItems(
          requestId: any(named: 'requestId'),
          issueId: any(named: 'issueId'),
          quantity: any(named: 'quantity'),
          reason: any(named: 'reason'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const ApiException(
          'Jumlah pengembalian melebihi.',
          status: 422,
          code: 'EXCEEDS_ISSUED_QUANTITY',
        ),
      );
      Get.put(AtkDeskDetailController(repository: repo, requestId: 8));

      await _pump(tester, const AtkDeskDetailView());
      await tester.ensureVisible(_button('Terima Pengembalian'));
      await tester.tap(_button('Terima Pengembalian'));
      await tester.pumpAndSettle();

      await tester.enterText(
        _inDialog(find.widgetWithText(TextField, 'Alasan pengembalian')),
        'Berlebih',
      );
      await tester.tap(_button('Catat pengembalian'));
      await tester.pumpAndSettle();

      expect(loads, 2);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        _inDialog(
          find.text('Jumlah melebihi barang yang masih bisa dikembalikan.'),
        ),
        findsOneWidget,
      );
      expect(
        _inDialog(find.text('Penyerahan ISS-1 • bisa dikembalikan 1 rim')),
        findsOneWidget,
      );
      // What was typed stays.
      expect(
        _inDialog(find.widgetWithText(TextField, 'Berlebih')),
        findsOneWidget,
      );

      await tester.tap(_inDialog(find.text('Batal')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('on a 320dp phone at double text size the return dialog and '
        'history do not overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final repo = _Repo();
      when(() => repo.deskRequest(8)).thenAnswer(
        (_) async => _detail(
          issues: [_returnable(returnable: 1, returned: 2), _unconfirmed],
          returns: [
            _returnRow(
              reason:
                  'Kemasan sobek dan beberapa lembar basah terkena air hujan',
            ),
          ],
        ),
      );
      Get.put(AtkDeskDetailController(repository: repo, requestId: 8));

      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AtkDeskDetailView(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -4000),
        4000,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        _button('Terima Pengembalian'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(_button('Terima Pengembalian'));
      await tester.pumpAndSettle();
      await tester.tap(_button('Terima Pengembalian'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('employee detail', () {
    testWidgets('shows "Riwayat Pengembalian" and what came back of each '
        'handover, with no way to record a return', (tester) async {
      final repo = _Repo();
      when(() => repo.request(7)).thenAnswer(
        (_) async => AtkRequestDetail(
          id: 7,
          number: 'IR-0007',
          itemName: 'Kertas A4',
          unit: 'rim',
          locationName: 'Gudang GA',
          quantity: 3,
          status: 'reserved',
          statusLabel: 'Direservasi',
          issuedQuantity: 3,
          issues: const [
            AtkHandover(
              id: 1,
              number: 'ISS-1',
              quantity: 3,
              issuedByName: 'Sari GA',
              issuedAt: '2026-11-12T03:00:00Z',
              receivedAt: '2026-11-12T04:00:00Z',
              returnedQuantity: 2,
            ),
          ],
          returnedQuantity: 2,
          returns: [_returnRow(reason: 'Kemasan sobek')],
        ),
      );
      Get.put(AtkRequestDetailController(repository: repo, requestId: 7));

      await _pump(tester, const AtkRequestDetailView());
      await tester.scrollUntilVisible(
        find.text('Alasan: Kemasan sobek'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Riwayat Pengembalian'), findsOneWidget);
      expect(find.text('RTN-0005 • 2 rim'), findsOneWidget);
      expect(find.text('Dicatat oleh: Sari GA'), findsOneWidget);
      // The header's total and the handover's own line.
      expect(find.text('Dikembalikan: 2 rim'), findsNWidgets(2));
      expect(find.text('Terima Pengembalian'), findsNothing);
    });

    testWidgets('no return yet shows no history section', (tester) async {
      final repo = _Repo();
      when(() => repo.request(7)).thenAnswer(
        (_) async => const AtkRequestDetail(
          id: 7,
          number: 'IR-0007',
          itemName: 'Kertas A4',
          unit: 'rim',
          locationName: 'Gudang GA',
          quantity: 3,
          status: 'reserved',
          statusLabel: 'Direservasi',
        ),
      );
      Get.put(AtkRequestDetailController(repository: repo, requestId: 7));

      await _pump(tester, const AtkRequestDetailView());

      expect(find.text('Riwayat Pengembalian'), findsNothing);
      expect(find.textContaining('Dikembalikan'), findsNothing);
    });
  });
}
