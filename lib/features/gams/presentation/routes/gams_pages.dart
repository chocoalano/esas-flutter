import 'package:get/get.dart';

import '../bindings/gams_bindings.dart';
import '../controllers/gams_create_controller.dart';
import '../views/gams_create_view.dart';
import '../views/gams_dashboard_view.dart';
import '../views/gams_request_tracking_views.dart';
import 'gams_routes.dart';

class GamsPages {
  const GamsPages._();

  /// The dashboard, and one form per request it offers (GAMS-01). The four
  /// sub-routes all used to render the dashboard itself, so every "Buat",
  /// "Pesan", "Pinjam" and "Daftar" — and the home screen's GAMS tiles —
  /// opened the screen the person was already on.
  static final List<GetPage> pages = [
    GetPage(
      name: GamsRoutes.gams,
      page: () => const GamsDashboardView(),
      binding: GamsDashboardBinding(),
      transition: Transition.noTransition,
    ),
    for (final (route, kind) in const [
      (GamsRoutes.serviceRequests, GamsCreateKind.serviceRequest),
      (GamsRoutes.spaceReservations, GamsCreateKind.spaceReservation),
      (GamsRoutes.vehicleBookings, GamsCreateKind.vehicleBooking),
      (GamsRoutes.visitorPasses, GamsCreateKind.visit),
    ])
      GetPage(
        name: route,
        page: () => GamsCreateView(kind: kind),
        binding: GamsCreateBinding(kind),
      ),
    GetPage(
      name: GamsRoutes.requests,
      page: () => const GamsRequestListView(),
      binding: GamsRequestListBinding(),
    ),
    GetPage(
      name: GamsRoutes.requestDetail,
      page: () => const GamsRequestDetailView(),
      binding: GamsRequestDetailBinding(),
    ),
  ];
}
