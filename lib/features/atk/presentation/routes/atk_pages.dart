import 'package:get/get.dart';

import '../bindings/atk_bindings.dart';
import '../views/atk_desk_detail_view.dart';
import '../views/atk_desk_list_view.dart';
import '../views/atk_request_create_view.dart';
import '../views/atk_request_detail_view.dart';
import '../views/atk_request_list_view.dart';
import 'atk_routes.dart';

class AtkPages {
  const AtkPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: AtkRoutes.requests,
      page: () => const AtkRequestListView(),
      binding: AtkRequestListBinding(),
    ),
    GetPage(
      name: AtkRoutes.create,
      page: () => const AtkRequestCreateView(),
      binding: AtkRequestCreateBinding(),
    ),
    GetPage(
      name: AtkRoutes.detail,
      page: () => const AtkRequestDetailView(),
      binding: AtkRequestDetailBinding(),
    ),
    GetPage(
      name: AtkRoutes.desk,
      page: () => const AtkDeskListView(),
      binding: AtkDeskListBinding(),
    ),
    GetPage(
      name: AtkRoutes.deskDetail,
      page: () => const AtkDeskDetailView(),
      binding: AtkDeskDetailBinding(),
    ),
  ];
}
