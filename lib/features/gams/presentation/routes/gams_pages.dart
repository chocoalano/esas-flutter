import 'package:get/get.dart';

import '../bindings/gams_bindings.dart';
import '../views/gams_dashboard_view.dart';
import 'gams_routes.dart';

class GamsPages {
  const GamsPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: GamsRoutes.gams,
      page: () => const GamsDashboardView(),
      binding: GamsDashboardBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: GamsRoutes.serviceRequests,
      page: () => const GamsDashboardView(),
      binding: GamsDashboardBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: GamsRoutes.spaceReservations,
      page: () => const GamsDashboardView(),
      binding: GamsDashboardBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: GamsRoutes.vehicleBookings,
      page: () => const GamsDashboardView(),
      binding: GamsDashboardBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: GamsRoutes.visitorPasses,
      page: () => const GamsDashboardView(),
      binding: GamsDashboardBinding(),
      transition: Transition.noTransition,
    ),
  ];
}

