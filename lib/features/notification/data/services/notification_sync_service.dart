import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/json_parsers.dart';
import '../../../auth/data/repositories/session_repository.dart';
import '../../../home/presentation/routes/home_routes.dart';
import '../../../permit/presentation/routes/permit_routes.dart';
import '../../../profile/presentation/routes/profile_routes.dart';
import '../../presentation/routes/notification_routes.dart';
import '../repositories/notification_repository.dart';

/// Only known resource types may select a route. The destination's API still
/// authorizes the resource against the current employee and workspace.
class NotificationDestination {
  const NotificationDestination(this.route, [this.arguments]);

  final String route;
  final Object? arguments;

  static NotificationDestination fromData(Map<String, dynamic> data) {
    final type = asString(data['type']) ?? '';
    final slipId = asInt(data['slip_id']);
    if (type == 'payslip.available' && slipId != null && slipId > 0) {
      return NotificationDestination(ProfileRoutes.payroll, {
        'slip_id': slipId,
      });
    }
    final permitId = asInt(data['permit_id']);
    if (type.startsWith('permit.') && permitId != null && permitId > 0) {
      return NotificationDestination(PermitRoutes.show, {'id': permitId});
    }
    final announcementId = asInt(data['announcement_id']);
    if (type == 'announcement.published' &&
        announcementId != null &&
        announcementId > 0) {
      return NotificationDestination(
        HomeRoutes.announcementDetail,
        announcementId,
      );
    }
    return const NotificationDestination(NotificationRoutes.notification);
  }
}

class NotificationSyncService extends GetxService with WidgetsBindingObserver {
  NotificationSyncService({
    required NotificationRepository repository,
    required SessionRepository session,
  }) : _repository = repository,
       _session = session;

  final NotificationRepository _repository;
  final SessionRepository _session;
  Future<void>? _refresh;
  bool _refreshAgain = false;
  Map<String, dynamic>? _pending;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  bool accepts(Map<String, dynamic> data) {
    if (!_session.isAuthenticated) return false;
    final recipient = asInt(data['recipient_id']);
    final tenant = asString(data['tenant_id']);
    if (recipient != null && recipient != _session.user?.id) return false;
    if (tenant != null && tenant != asString(_session.user?.raw['tenant_id'])) {
      return false;
    }
    return true;
  }

  Future<void> received(Map<String, dynamic> data) async {
    if (accepts(data)) await refresh();
  }

  Future<void> refresh() {
    if (!_session.isAuthenticated) return Future.value();
    if (_refresh != null) {
      _refreshAgain = true;
      return _refresh!;
    }
    final task = _fetch();
    _refresh = task;
    return task.whenComplete(() => _refresh = null);
  }

  Future<void> _fetch() async {
    do {
      _refreshAgain = false;
      final token = _session.token;
      try {
        final page = await _repository.page(page: 1, perPage: 1);
        // A logout or account switch while HTTP was in flight retires the reply.
        if (token != _session.token || !_session.isAuthenticated) return;
        _session.noteUnreadNotifications(page.unreadCount);
        _session.notificationRevision.value++;
      } on Object catch (error) {
        AppLogger.warning(
          'Notification refresh failed (${error.runtimeType}).',
        );
      }
    } while (_refreshAgain && _session.isAuthenticated);
  }

  void open(Map<String, dynamic> data) {
    _pending = Map<String, dynamic>.from(data);
    onSessionReady();
  }

  void onSessionReady() {
    unawaited(refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = _pending;
      if (data == null ||
          !_session.isAuthenticated ||
          Get.key.currentState == null) {
        return;
      }
      _pending = null;
      if (!accepts(data)) return;
      final destination = NotificationDestination.fromData(data);
      if (Get.currentRoute != destination.route ||
          destination.arguments != null) {
        Get.toNamed(
          destination.route,
          arguments: destination.arguments,
          preventDuplicates: destination.arguments == null,
        );
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }
}
