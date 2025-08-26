import 'package:esas/app/services/api_provider.dart';
import 'package:get/get.dart';

import '../controllers/announcement_controller.dart';

class AnnouncementDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AnnouncementController>(() => AnnouncementController());
    Get.lazyPut<ApiProvider>(() => ApiProvider());
  }
}
