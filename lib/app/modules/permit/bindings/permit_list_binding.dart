import 'package:get/get.dart';

import '../controllers/permit_create_controller.dart';
import '../controllers/permit_list_controller.dart';

class PermitListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PermitListController>(() => PermitListController());
    Get.lazyPut<PermitCreateController>(() => PermitCreateController());
  }
}
