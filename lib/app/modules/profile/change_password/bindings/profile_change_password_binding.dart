import 'package:get/get.dart';

import '../controllers/profile_change_password_controller.dart';

class ProfileChangePasswordBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileChangePasswordController>(
      () => ProfileChangePasswordController(),
    );
  }
}
