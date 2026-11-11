import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/home/data/models/announcement.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/controllers/announcement_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements HomeRepository {}

Announcement item(int id) => Announcement.fromJson({'id': id, 'title': 'A$id'});

List<Announcement> rows(int from, [int count = 10]) => [
  for (var i = from; i < from + count; i++) item(i),
];

void main() {
  late _Repo repo;

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
  });

  tearDown(Get.reset);

  void answers(Future<List<Announcement>> Function(int page) reply) => when(
    () => repo.announcements(
      page: any(named: 'page'),
      perPage: any(named: 'perPage'),
    ),
  ).thenAnswer((i) => reply(i.namedArguments[#page] as int));

  // HOME-15. A failure was swallowed into an empty list: "Belum ada
  // pengumuman", no retry, and paging switched off for good.
  test('a failed load is an error, not an empty list', () async {
    answers((_) async => throw const ApiException('Offline', code: 'network_unreachable'));

    final controller = AnnouncementController(repository: repo)..onInit();
    await pumpEventQueue();

    expect(controller.loadError.value, isNotNull);
  });

  test('a failed load-more keeps paging possible', () async {
    var fail = true;
    answers((page) async {
      if (page == 2 && fail) {
        throw const ApiException('Offline', code: 'network_unreachable');
      }
      return rows((page - 1) * 10);
    });
    final controller = AnnouncementController(repository: repo)..onInit();
    await pumpEventQueue();

    await controller.loadMore();
    expect(controller.hasMore.value, isTrue);
    expect(controller.page.value, 1);

    fail = false;
    await controller.loadMore();
    expect(controller.lists, hasLength(20));
  });

  // HOME-16. A page requested before a refresh must not land after it.
  test('a load-more that started before a refresh is dropped', () async {
    final pageTwo = Completer<List<Announcement>>();
    answers((page) => page == 2 ? pageTwo.future : Future.value(rows(0)));
    final controller = AnnouncementController(repository: repo)..onInit();
    await pumpEventQueue();

    unawaited(controller.loadMore());
    await controller.resetAndFetch();
    pageTwo.complete(rows(10));
    await pumpEventQueue();

    expect(controller.lists, hasLength(10));
    expect(controller.page.value, 1);
  });
}
