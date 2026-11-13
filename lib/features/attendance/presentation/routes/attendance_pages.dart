import 'package:get/get.dart';

import '../bindings/attendance_bindings.dart';
import '../views/attendance_list_view.dart';
import '../views/attendance_view.dart';
import '../views/overtime_list_view.dart';
import '../widgets/attendance_device_gate.dart';
import 'attendance_routes.dart';

/// The attendance feature's slice of the route table.
class AttendancePages {
  const AttendancePages._();

  static final List<GetPage> pages = [
    GetPage(
      name: AttendanceRoutes.overtime,
      page: () => const OvertimeListView(),
      binding: OvertimeListBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: AttendanceRoutes.attendance,
      page: () => const AttendanceView(),
      binding: AttendanceBinding(),
      transition: Transition.noTransition,
      // ADR-D: the attendance-device gate at the entry. Wraps the capture
      // screen only; the history child is passed through unchanged.
      middlewares: [AttendanceDeviceGateMiddleware()],
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
