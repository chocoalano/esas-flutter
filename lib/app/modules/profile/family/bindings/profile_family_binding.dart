import 'package:get/get.dart';

import '../controllers/profile_family_controller.dart';

class ProfileFamilyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileFamilyController>(
      () => ProfileFamilyController(),
    );
  }
}
