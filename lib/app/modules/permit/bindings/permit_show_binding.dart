import 'package:get/get.dart';

import '../controllers/permit_show_controller.dart';

class PermitShowBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PermitShowController>(() => PermitShowController());
  }
}
