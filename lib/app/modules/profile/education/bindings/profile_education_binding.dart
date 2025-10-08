import 'package:get/get.dart';

import '../controllers/profile_education_controller.dart';

class ProfileEducationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileEducationController>(
      () => ProfileEducationController(),
    );
  }
}
