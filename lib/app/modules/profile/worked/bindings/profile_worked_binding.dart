import 'package:get/get.dart';

import '../controllers/profile_worked_controller.dart';

class ProfileWorkedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileWorkedController>(
      () => ProfileWorkedController(),
    );
  }
}
