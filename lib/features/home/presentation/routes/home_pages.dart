import 'package:get/get.dart';

import '../bindings/home_bindings.dart';
import '../views/activity_view.dart';
import '../views/announcement_detail_view.dart';
import '../views/announcement_view.dart';
import '../views/home_view.dart';
import 'home_routes.dart';

/// The home feature's slice of the route table.
class HomePages {
  const HomePages._();

  static final List<GetPage> pages = [
    GetPage(
      name: HomeRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
      transition: Transition.noTransition,
      children: [
        GetPage(
          name: HomeRoutes.announcementSegment,
          page: () => const AnnouncementView(),
          binding: AnnouncementBinding(),
          transition: Transition.noTransition,
          children: [
            GetPage(
              name: HomeRoutes.announcementDetailSegment,
              page: () => const AnnouncementDetailView(),
              binding: AnnouncementDetailBinding(),
              transition: Transition.noTransition,
            ),
          ],
        ),
        GetPage(
          name: HomeRoutes.activitySegment,
          page: () => const ActivityView(),
          binding: ActivityBinding(),
          transition: Transition.noTransition,
        ),
      ],
    ),
  ];
}
