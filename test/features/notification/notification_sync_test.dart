import 'dart:async';

import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/notification/data/models/notification.dart';
import 'package:esas/features/notification/data/repositories/notification_repository.dart';
import 'package:esas/features/notification/data/services/notification_sync_service.dart';
import 'package:esas/features/notification/presentation/controllers/notification_controller.dart';
import 'package:esas/features/notification/presentation/routes/notification_routes.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNotifications extends Fake implements NotificationRepository {
  int requests = 0;
  Completer<NotificationPage>? pending;
  @override
  Future<NotificationPage> page({
    required int page,
    required int perPage,
    bool unreadOnly = false,
  }) async {
    requests++;
    final delayed = pending;
    pending = null;
    if (delayed != null) return delayed.future;
    return const NotificationPage(rows: [], unreadCount: 12);
  }
}

void main() {
  test(
    'template body remains readable and structured payload survives parsing',
    () {
      final data = NotificationData.fromJson({
        'title': 'Cuti',
        'body': 'Disetujui',
        'permit_id': 41,
        'type': 'permit.decided',
      });
      expect(data.message, 'Disetujui');
      expect(data.toJson()['permit_id'], 41);
    },
  );

  test('only supported types select resource routes', () {
    expect(
      NotificationDestination.fromData({
        'type': 'permit.decided',
        'permit_id': '41',
      }).route,
      PermitRoutes.show,
    );
    expect(
      NotificationDestination.fromData({
        'type': 'unknown',
        'url': 'https://example.com',
        'permit_id': 41,
      }).route,
      NotificationRoutes.notification,
    );
    expect(
      NotificationDestination.fromData({
        'type': 'permit.decided',
        'permit_id': -1,
      }).route,
      NotificationRoutes.notification,
    );
  });

  test(
    'incoming messages update unread state only for the active recipient and tenant',
    () async {
      final session = SessionRepository(
        tokenStorage: InMemoryTokenStorage(),
        localStorage: InMemoryLocalStorage(),
      );
      await session.save(
        token: 'test-token',
        user: AuthUser.fromJson({'id': 7, 'tenant_id': 'workspace-a'}),
      );
      final repository = FakeNotifications();
      final sync = NotificationSyncService(
        repository: repository,
        session: session,
      );
      await sync.received({'recipient_id': '8', 'tenant_id': 'workspace-a'});
      await sync.received({'recipient_id': '7', 'tenant_id': 'workspace-b'});
      expect(repository.requests, 0);
      await sync.received({'recipient_id': '7', 'tenant_id': 'workspace-a'});
      expect(session.unreadNotifications, 12);
      expect(session.notificationRevision.value, 1);
      await session.clear();
      await sync.received({'recipient_id': '7', 'tenant_id': 'workspace-a'});
      expect(repository.requests, 1);
      expect(session.unreadNotifications, isNull);
    },
  );
  test(
    'an in-flight response cannot republish the previous account badge',
    () async {
      final session = SessionRepository(
        tokenStorage: InMemoryTokenStorage(),
        localStorage: InMemoryLocalStorage(),
      );
      await session.save(
        token: 'old-token',
        user: AuthUser.fromJson({'id': 7}),
      );
      final delayed = Completer<NotificationPage>();
      final repository = FakeNotifications()..pending = delayed;
      final sync = NotificationSyncService(
        repository: repository,
        session: session,
      );
      final refresh = sync.refresh();
      await session.clear();
      await session.save(
        token: 'new-token',
        user: AuthUser.fromJson({'id': 8}),
      );
      delayed.complete(const NotificationPage(rows: [], unreadCount: 99));
      await refresh;
      expect(session.unreadNotifications, isNull);
      expect(session.notificationRevision.value, 0);
    },
  );

  test(
    'messages arriving during a refresh trigger one catch-up request',
    () async {
      final session = SessionRepository(
        tokenStorage: InMemoryTokenStorage(),
        localStorage: InMemoryLocalStorage(),
      );
      await session.save(token: 'token', user: AuthUser.fromJson({'id': 7}));
      final delayed = Completer<NotificationPage>();
      final repository = FakeNotifications()..pending = delayed;
      final sync = NotificationSyncService(
        repository: repository,
        session: session,
      );
      final first = sync.refresh();
      final second = sync.refresh();
      final third = sync.refresh();
      delayed.complete(const NotificationPage(rows: [], unreadCount: 1));
      await Future.wait([first, second, third]);
      expect(repository.requests, 2);
      expect(session.unreadNotifications, 12);
    },
  );
  test(
    'a stale inbox refresh cannot overwrite the newest unread count',
    () async {
      final session = SessionRepository(
        tokenStorage: InMemoryTokenStorage(),
        localStorage: InMemoryLocalStorage(),
      );
      final delayed = Completer<NotificationPage>();
      final repository = FakeNotifications()..pending = delayed;
      final controller = NotificationController(
        repository: repository,
        session: session,
      );
      final oldRefresh = controller.refreshNotifications();
      await controller.refreshNotifications();
      delayed.complete(const NotificationPage(rows: [], unreadCount: 99));
      await oldRefresh;
      expect(controller.unreadCount, 12);
      expect(session.unreadNotifications, 12);
      expect(controller.isLoading.value, isFalse);
    },
  );
}
