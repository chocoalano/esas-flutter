import 'package:get/get.dart';

import '../controllers/profile_experience_controller.dart';

class ProfileExperienceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileExperienceController>(
      () => ProfileExperienceController(),
    );
  }
}
