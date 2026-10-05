import 'package:get/get.dart';

import '../bindings/notification_binding.dart';
import '../views/notification_view.dart';
import 'notification_routes.dart';

/// The notification feature's slice of the route table.
class NotificationPages {
  const NotificationPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: NotificationRoutes.notification,
      page: () => const NotificationView(),
      binding: NotificationBinding(),
      transition: Transition.noTransition,
    ),
  ];
}
