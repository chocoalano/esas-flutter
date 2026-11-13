import 'package:get/get.dart';

import '../bindings/device_bindings.dart';
import '../views/device_enrollment_view.dart';
import 'device_routes.dart';

/// The attendance-device slice of the route table (ADR-D).
class DevicePages {
  const DevicePages._();

  static final List<GetPage> pages = [
    GetPage(
      name: DeviceRoutes.enrollment,
      page: () => const DeviceEnrollmentView(),
      binding: DeviceEnrollmentBinding(),
    ),
  ];
}
