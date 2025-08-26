import 'package:get/get.dart';

import '../controllers/profile_payroll_controller.dart';

class ProfilePayrollBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfilePayrollController>(
      () => ProfilePayrollController(),
    );
  }
}
