import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/repositories/session_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/services/notification_api_service.dart';
import '../controllers/notification_controller.dart';

class NotificationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NotificationController>(
      () => NotificationController(
        repository: NotificationRepository(
          NotificationApiService(Get.find<ApiClient>()),
        ),
        // Dijaga `isRegistered` karena harness uji membangun layar ini tanpa
        // komposisi penuh — pola yang sama dipakai `HomeView._signInAgain`.
        session: Get.isRegistered<SessionRepository>()
            ? Get.find<SessionRepository>()
            : null,
      ),
    );
  }
}
