import 'package:get/get.dart';

import '../bindings/setup_binding.dart';
import '../views/setup_view.dart';
import 'setup_routes.dart';

/// The setup feature's slice of the route table.
class SetupPages {
  const SetupPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: SetupRoutes.setup,
      page: () => const SetupView(),
      binding: SetupBinding(),
      transition: Transition.noTransition,
    ),
  ];
}
