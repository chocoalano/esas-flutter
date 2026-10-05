import 'package:get/get.dart';

import '../bindings/attendance_bindings.dart';
import '../views/attendance_list_view.dart';
import '../views/attendance_view.dart';
import 'attendance_routes.dart';

/// The attendance feature's slice of the route table.
class AttendancePages {
  const AttendancePages._();

  static final List<GetPage> pages = [
    GetPage(
      name: AttendanceRoutes.attendance,
      page: () => const AttendanceView(),
      binding: AttendanceBinding(),
      transition: Transition.noTransition,
      children: [
        GetPage(
          name: AttendanceRoutes.listSegment,
          page: () => const AttendanceListView(),
          binding: AttendanceListBinding(),
          transition: Transition.noTransition,
        ),
      ],
    ),
  ];
}
