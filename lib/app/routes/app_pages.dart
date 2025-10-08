// ignore_for_file: constant_identifier_names

import 'package:esas/app/modules/home/announcement/bindings/announcement_detail_binding.dart';
import 'package:esas/app/modules/home/announcement/views/announcement_detail_view.dart';
import 'package:get/get.dart';

import '../modules/attendance/bindings/attendance_binding.dart';
import '../modules/attendance/list/bindings/attendance_list_binding.dart';
import '../modules/attendance/list/views/attendance_list_view.dart';
import '../modules/attendance/views/attendance_view.dart';
import '../modules/home/activity/bindings/activity_binding.dart';
import '../modules/home/activity/views/activity_view.dart';
import '../modules/home/announcement/bindings/announcement_binding.dart';
import '../modules/home/announcement/views/announcement_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/notification/bindings/notification_binding.dart';
import '../modules/notification/views/notification_view.dart';
import '../modules/permit/bindings/permit_binding.dart';
import '../modules/permit/bindings/permit_list_binding.dart';
import '../modules/permit/bindings/permit_show_binding.dart';
import '../modules/permit/views/permit_create.dart';
import '../modules/permit/views/permit_list_view.dart';
import '../modules/permit/views/permit_show.dart';
import '../modules/permit/views/permit_view.dart';
import '../modules/profile/profile_pages.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
      transition: Transition.noTransition,
      children: [
        GetPage(
          name: _Paths.ANNOUNCEMENT,
          page: () => const AnnouncementView(),
          binding: AnnouncementBinding(),
          transition: Transition.noTransition,
          children: [
            GetPage(
              name: _Paths.ANNOUNCEMENT_DETAIL,
              page: () => const AnnouncementDetailView(),
              binding: AnnouncementDetailBinding(),
              transition: Transition.noTransition,
            ),
          ],
        ),
        GetPage(
          name: _Paths.ACTIVITY,
          page: () => const ActivityView(),
          binding: ActivityBinding(),
          transition: Transition.noTransition,
        ),
      ],
    ),
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: _Paths.ATTENDANCE,
      page: () => AttendanceView(),
      binding: AttendanceBinding(),
      transition: Transition.noTransition,
      children: [
        GetPage(
          name: _Paths.ATTENDANCE_LIST,
          page: () => const AttendanceListView(),
          binding: AttendanceListBinding(),
          transition: Transition.noTransition,
        ),
      ],
    ),
    GetPage(
      name: _Paths.PERMIT,
      page: () => const PermitView(),
      binding: PermitBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: _Paths.PERMIT_LIST,
      page: () => const PermitListView(),
      binding: PermitListBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: _Paths.PERMIT_SHOW,
      page: () => const PermitShowView(),
      binding: PermitShowBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: _Paths.PERMIT_CREATE,
      page: () => PermitCreate(),
      binding: PermitShowBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: _Paths.NOTIFICATION,
      page: () => NotificationView(),
      binding: NotificationBinding(),
      transition: Transition.noTransition,
    ),
    ...ProfilePages.routes,
  ];
}
