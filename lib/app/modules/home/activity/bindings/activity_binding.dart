import 'package:esas/app/services/api_provider.dart';
import 'package:get/get.dart';

import '../controllers/activity_controller.dart';

class ActivityBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ActivityController>(() => ActivityController());
    Get.lazyPut<ApiProvider>(() => ApiProvider());
  }
}
