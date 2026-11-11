import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/notification/data/repositories/notification_repository.dart';
import 'package:esas/features/notification/data/services/notification_sync_service.dart';
import 'package:esas/features/notification/presentation/routes/notification_routes.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Notifications extends Fake implements NotificationRepository {
  int requests = 0;

  @override
  Future<NotificationPage> page({
    required int page,
    required int perPage,
    bool unreadOnly = false,
  }) async {
    requests++;
    return const NotificationPage(rows: [], unreadCount: 3);
  }
}

void main() {
  late SessionRepository session;
  late _Notifications repository;
  late NotificationSyncService sync;

  setUp(() async {
    Get.testMode = true;
    session = SessionRepository(
      tokenStorage: InMemoryTokenStorage(),
      localStorage: InMemoryLocalStorage(),
    );
    await session.save(token: 'token', user: AuthUser.fromJson({'id': 7}));
    repository = _Notifications();
    sync = NotificationSyncService(repository: repository, session: session);
  });

  tearDown(Get.reset);

  Future<void> pumpApp(WidgetTester tester, String initial) async {
    GetPage page(String name) => GetPage(
      name: name,
      page: () => Scaffold(body: Text('LAYAR $name')),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: initial,
        getPages: [
          page('/home'),
          page(NotificationRoutes.notification),
          page(PermitRoutes.show),
        ],
      ),
    );
  }

  // NOTIF-02. Opening a row from the list asked for a fresh count, which bumped
  // the session's revision, which the list answers by reloading page one —
  // the pages loaded below it and the scroll position went with it.
  testWidgets('opening a row from the list does not reload the list', (
    tester,
  ) async {
    await pumpApp(tester, NotificationRoutes.notification);

    sync.open({'type': 'permit.decided', 'permit_id': 41}, refresh: false);
    await tester.pumpAndSettle();

    expect(repository.requests, 0);
    expect(session.notificationRevision.value, 0);
    expect(Get.currentRoute, PermitRoutes.show);
  });

  // NOTIF-03. A push with no resource of its own pushed the Notifikasi tab on
  // top of whatever was open. Back from a tab offers to leave the app, so it
  // did — with a page still underneath.
  testWidgets('a generic push opens the Notifikasi tab as a tab', (
    tester,
  ) async {
    await pumpApp(tester, '/home');

    sync.open({'type': 'system.notice'});
    await tester.pumpAndSettle();

    expect(Get.currentRoute, NotificationRoutes.notification);
    expect(Get.key.currentState!.canPop(), isFalse);
  });

  testWidgets('a push about a request still stacks over the current page', (
    tester,
  ) async {
    await pumpApp(tester, '/home');

    sync.open({'type': 'permit.decided', 'permit_id': 41});
    await tester.pumpAndSettle();

    expect(Get.currentRoute, PermitRoutes.show);
    expect(Get.key.currentState!.canPop(), isTrue);
  });
}
