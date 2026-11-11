import 'package:get/get.dart';

import '../bindings/itms_bindings.dart';
import '../views/itms_dashboard_view.dart';
import '../views/itms_ticket_create_view.dart';
import 'itms_routes.dart';

class ItmsPages {
  const ItmsPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: ItmsRoutes.itms,
      page: () => const ItmsDashboardView(),
      binding: ItmsDashboardBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: ItmsRoutes.tickets,
      page: () => const ItmsDashboardView(),
      binding: ItmsDashboardBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: ItmsRoutes.catalog,
      page: () => const ItmsDashboardView(),
      binding: ItmsDashboardBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: ItmsRoutes.knowledge,
      page: () => const ItmsDashboardView(),
      binding: ItmsDashboardBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: ItmsRoutes.ticketCreate,
      page: () => const ItmsTicketCreateView(),
      binding: ItmsTicketCreateBinding(),
    ),
  ];
}
