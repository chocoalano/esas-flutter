import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/atk/data/models/atk_models.dart';
import 'package:esas/features/atk/data/repositories/atk_repository.dart';
import 'package:esas/features/atk/presentation/controllers/atk_request_create_controller.dart';
import 'package:esas/features/atk/presentation/views/atk_request_create_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements AtkRepository {}

void main() {
  late _Repo repo;

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
  });

  tearDown(Get.reset);

  void options() {
    when(() => repo.items()).thenAnswer(
      (_) async => const [AtkItem(id: 3, name: 'Pulpen', unit: 'pcs')],
    );
    when(() => repo.locations()).thenAnswer(
      (_) async => const [
        AtkLocation(id: 9, name: 'Gudang GA'),
        AtkLocation(id: 10, name: 'Lantai 2'),
      ],
    );
  }

  group('asking for ATK', () {
    late AtkRequestCreateController controller;
    final keys = <String>[];

    setUp(() async {
      keys.clear();
      options();
      controller = AtkRequestCreateController(repository: repo);
      controller.onInit();
      await pumpEventQueue();
    });

    void answer(Future<({int id, String number})> Function() reply) {
      when(
        () => repo.createRequest(
          itemId: any(named: 'itemId'),
          locationId: any(named: 'locationId'),
          quantity: any(named: 'quantity'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) {
        keys.add(invocation.namedArguments[#idempotencyKey] as String);
        return reply();
      });
    }

    test('needs an item, a pickup location and at least one', () async {
      expect(controller.validate(), 'Pilih barang ATK yang diminta.');
      controller.itemId.value = 3;
      expect(controller.validate(), 'Pilih lokasi pengambilan.');
      controller.locationId.value = 9;
      controller.quantityC.text = '0';
      expect(controller.validate(), 'Jumlah minimal 1.');
      controller.quantityC.text = '';
      expect(controller.validate(), 'Jumlah minimal 1.');
      controller.quantityC.text = '2';
      expect(controller.validate(), isNull);

      // Nothing is sent while the form is invalid.
      controller.itemId.value = null;
      expect(await controller.submit(), isNull);
      expect(controller.error.value, 'Pilih barang ATK yang diminta.');
      verifyNever(
        () => repo.createRequest(
          itemId: any(named: 'itemId'),
          locationId: any(named: 'locationId'),
          quantity: any(named: 'quantity'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    test('the stepper never goes below one', () {
      controller.decrement();
      expect(controller.quantity, 1);
      controller.increment();
      controller.increment();
      expect(controller.quantity, 3);
    });

    test(
      'sends the item, location and quantity, and returns the number',
      () async {
        controller.itemId.value = 3;
        controller.locationId.value = 9;
        controller.quantityC.text = '4';
        answer(() async => (id: 21, number: 'IR-0021'));

        expect(await controller.submit(), 'IR-0021');
        verify(
          () => repo.createRequest(
            itemId: 3,
            locationId: 9,
            quantity: 4,
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).called(1);
        expect(keys.single, isNotEmpty);
      },
    );

    test(
      'a lost answer keeps the key, so the retry cannot file twice',
      () async {
        controller.itemId.value = 3;
        controller.locationId.value = 9;

        answer(
          () async => throw const ApiException('Server sibuk', status: 503),
        );
        expect(await controller.submit(), isNull);
        expect(
          controller.error.value,
          contains('tidak akan mencatatnya dua kali'),
        );

        answer(
          () async => throw const ApiException('offline', code: 'timeout'),
        );
        expect(await controller.submit(), isNull);

        answer(() async => (id: 21, number: 'IR-0021'));
        expect(await controller.submit(), 'IR-0021');

        expect(keys, hasLength(3));
        expect(keys.toSet(), hasLength(1));
      },
    );

    test('a definite refusal ends the attempt; the next one is new', () async {
      controller.itemId.value = 3;
      controller.locationId.value = 9;

      answer(
        () async => throw const ApiException(
          'Akun Anda belum terhubung dengan data pekerja.',
          status: 422,
          code: 'WORKER_REQUIRED',
        ),
      );
      expect(await controller.submit(), isNull);
      expect(
        controller.error.value,
        'Akun Anda belum terhubung dengan data pekerja.',
      );

      answer(() async => (id: 22, number: 'IR-0022'));
      expect(await controller.submit(), 'IR-0022');

      expect(keys, hasLength(2));
      expect(keys.first, isNot(keys.last));
    });
  });

  testWidgets(
    'items that fail to load are an error with a retry, not an empty dropdown',
    (tester) async {
      var calls = 0;
      when(() => repo.items()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw const ApiException('Tidak ada koneksi', code: 'timeout');
        }
        return const [AtkItem(id: 3, name: 'Pulpen', unit: 'pcs')];
      });
      when(
        () => repo.locations(),
      ).thenAnswer((_) async => const [AtkLocation(id: 9, name: 'Gudang GA')]);
      Get.put(AtkRequestCreateController(repository: repo));

      await tester.pumpWidget(
        const GetMaterialApp(home: AtkRequestCreateView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat daftar barang'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);

      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('Gagal memuat daftar barang'), findsNothing);
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
      expect(find.text('Kirim permintaan'), findsOneWidget);
    },
  );
}
