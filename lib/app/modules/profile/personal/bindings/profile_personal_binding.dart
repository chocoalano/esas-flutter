import 'package:get/get.dart';

import '../controllers/profile_personal_controller.dart';

class ProfilePersonalBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfilePersonalController>(
      () => ProfilePersonalController(),
    );
  }
}
