import 'package:get/get.dart';

import '../controllers/permit_controller.dart';

class PermitBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PermitController>(
      () => PermitController(),
    );
  }
}
