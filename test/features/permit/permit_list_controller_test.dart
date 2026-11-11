import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/data/models/leave_type.dart';
import 'package:esas/features/permit/data/repositories/permit_repository.dart';
import 'package:esas/features/permit/presentation/controllers/permit_list_controller.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:esas/features/permit/presentation/views/permit_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements PermitRepository {}

Permit permit(int id) => Permit.fromJson({
  'id': id,
  'permit_numbers': 'PRM-$id',
  'start_date': '2026-11-12',
  'end_date': '2026-11-12',
  'permit_type': {'id': 1, 'name': 'Cuti'},
});

List<Permit> pageOf(int from, [int count = 10]) =>
    [for (var i = from; i < from + count; i++) permit(i)];

void main() {
  late _Repo repo;

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
  });

  tearDown(Get.reset);

  void listAnswers(Future<List<Permit>> Function(Invocation) answer) => when(
    () => repo.list(
      typeId: any(named: 'typeId'),
      page: any(named: 'page'),
      perPage: any(named: 'perPage'),
    ),
  ).thenAnswer(answer);

  Future<PermitListController> open({LeaveType? type}) async {
    final controller = PermitListController(repository: repo);
    if (type != null) controller.permitType.value = type;
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    return controller;
  }

  // PRMT-05. "Pengajuan" on the home screen opens this list with no type.
  // `GET /permits` without `type` is every request of this person's; the
  // list used to return nothing at all, and say "Belum ada pengajuan".
  test('with no type, every request is listed', () async {
    listAnswers((_) async => pageOf(1, 3));

    final controller = await open();

    expect(controller.permits, hasLength(3));
    verify(
      () => repo.list(
        typeId: null,
        page: 1,
        perPage: any(named: 'perPage'),
      ),
    ).called(1);
  });

  // PRMT-14. A refresh that fails is not an empty history.
  group('a failed refresh', () {
    test('keeps what was already on screen, and says it failed', () async {
      var call = 0;
      listAnswers((_) async {
        call++;
        if (call == 1) return pageOf(1, 3);
        throw const ApiException('Offline', code: 'network_unreachable');
      });
      final controller = await open();

      await controller.resetAndFetch();

      expect(controller.permits, hasLength(3));
      expect(controller.loadError.value, isNotNull);
    });

    test('with nothing on screen, is an error and not an empty list', () async {
      listAnswers(
        (_) async =>
            throw const ApiException('Offline', code: 'network_unreachable'),
      );

      final controller = await open();

      expect(controller.permits, isEmpty);
      expect(controller.loadError.value, isNotNull);
    });
  });

  // PRMT-15. A page requested before a refresh must not land after it.
  test('a load-more that started before a refresh is dropped', () async {
    final pageTwo = Completer<List<Permit>>();
    listAnswers((invocation) {
      final page = invocation.namedArguments[#page] as int;
      return page == 2 ? pageTwo.future : Future.value(pageOf(1));
    });
    final controller = await open();

    unawaited(controller.loadMorePermits());
    final refresh = controller.resetAndFetch();
    await refresh;
    pageTwo.complete(pageOf(11));
    await Future<void>.delayed(Duration.zero);

    expect(controller.permits, hasLength(10));
    expect(controller.page.value, 1);
    expect(controller.permits.map((p) => p.id).toSet(), hasLength(10));
  });

  test('a failed load-more does not skip the page', () async {
    var failNext = false;
    listAnswers((invocation) async {
      final page = invocation.namedArguments[#page] as int;
      if (page == 2 && failNext) {
        throw const ApiException('Offline', code: 'network_unreachable');
      }
      return pageOf((page - 1) * 10 + 1);
    });
    final controller = await open();

    failNext = true;
    await controller.loadMorePermits();
    expect(controller.page.value, 1);

    failNext = false;
    await controller.loadMorePermits();
    expect(controller.permits, hasLength(20));
  });

  // UAT review A5. `_fetch` set `hasMore` itself, before the caller checked
  // whether its list still existed: a short page answering a load-more that
  // started before a refresh switched paging off for the new list.
  test('a stale short page does not switch paging off', () async {
    final second = Completer<List<Permit>>();
    listAnswers((invocation) async {
      final page = invocation.namedArguments[#page] as int;
      if (page == 2) return second.future;
      return pageOf((page - 1) * 10 + 1);
    });
    final controller = await open();

    final stale = controller.loadMorePermits();
    await pumpEventQueue();
    await controller.resetAndFetch();
    expect(controller.hasMore.value, isTrue);

    second.complete(const <Permit>[]);
    await stale;

    expect(controller.hasMore.value, isTrue);
  });

  group('the list screen', () {
    Future<void> pumpList(WidgetTester tester, PermitListController c) async {
      Get.put<PermitListController>(c);
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: PermitRoutes.list,
          getPages: [
            GetPage(name: PermitRoutes.list, page: () => const PermitListView()),
            GetPage(
              name: PermitRoutes.permit,
              page: () => const Scaffold(body: Text('Pilih jenis izin')),
            ),
            GetPage(
              name: PermitRoutes.create,
              page: () => const Scaffold(body: Text('Formulir')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a failure is not shown as an empty history', (tester) async {
      listAnswers(
        (_) async =>
            throw const ApiException('Offline', code: 'network_unreachable'),
      );
      final c = PermitListController(repository: repo);

      await pumpList(tester, c);

      expect(find.text('Belum ada pengajuan'), findsNothing);
      expect(find.text('Gagal memuat pengajuan'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('with no type, Ajukan asks which kind first', (tester) async {
      listAnswers((_) async => const <Permit>[]);
      final c = PermitListController(repository: repo);

      await pumpList(tester, c);
      await tester.tap(find.text('Ajukan'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih jenis izin'), findsOneWidget);
    });
  });
}
