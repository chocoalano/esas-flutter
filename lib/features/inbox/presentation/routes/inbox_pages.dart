import 'package:get/get.dart';

import '../bindings/inbox_bindings.dart';
import '../views/unified_inbox_view.dart';
import 'inbox_routes.dart';

class InboxPages {
  const InboxPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: InboxRoutes.inbox,
      page: () => const UnifiedInboxView(),
      binding: InboxBinding(),
      transition: Transition.noTransition,
    ),
  ];
}

