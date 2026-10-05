import 'package:get/get.dart';

import '../../features/attendance/presentation/routes/attendance_pages.dart';
import '../../features/auth/presentation/routes/auth_pages.dart';
import '../../features/auth/presentation/routes/auth_routes.dart';
import '../../features/home/presentation/routes/home_pages.dart';
import '../../features/notification/presentation/routes/notification_pages.dart';
import '../../features/permit/presentation/routes/permit_pages.dart';
import '../../features/profile/presentation/routes/profile_pages.dart';
import '../../features/setup/presentation/routes/setup_pages.dart';

/// The application's route table — an aggregator, and nothing else.
///
/// Each feature owns its own pages and its own path constants under
/// `features/<f>/presentation/routes/`. This file exists so `GetMaterialApp`
/// has one list to be handed, and so adding a feature is one import and one
/// spread rather than an edit inside a 120-line switchboard.
///
/// There is deliberately no central `Routes` class any more. A destination is
/// named by the feature that owns it — `HomeRoutes.home`, `PermitRoutes.create`
/// — which is what makes a feature's routes deletable with the feature. The
/// route *paths* are unchanged; only the constants that spell them moved.
class AppPages {
  const AppPages._();

  static const initial = AuthRoutes.splash;

  static final List<GetPage> routes = [
    ...AuthPages.pages,
    ...SetupPages.pages,
    ...HomePages.pages,
    ...AttendancePages.pages,
    ...PermitPages.pages,
    ...NotificationPages.pages,
    ...ProfilePages.pages,
  ];
}
