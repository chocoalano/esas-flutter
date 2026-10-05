import 'package:get/get.dart';

import '../bindings/permit_bindings.dart';
import '../views/permit_create_view.dart';
import '../views/permit_list_view.dart';
import '../views/permit_show_view.dart';
import '../views/permit_view.dart';
import 'permit_routes.dart';

/// The permit feature's slice of the route table.
class PermitPages {
  const PermitPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: PermitRoutes.permit,
      page: () => const PermitView(),
      binding: PermitBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: PermitRoutes.list,
      page: () => const PermitListView(),
      binding: PermitListBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: PermitRoutes.show,
      page: () => const PermitShowView(),
      binding: PermitShowBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: PermitRoutes.create,
      page: () => const PermitCreateView(),
      binding: PermitCreateBinding(),
      transition: Transition.noTransition,
    ),
  ];
}
