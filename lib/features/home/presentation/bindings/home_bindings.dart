import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../../../features/auth/data/repositories/session_repository.dart';
import '../../data/repositories/home_repository.dart';
import '../../data/services/home_api_service.dart';
import '../controllers/activity_controller.dart';
import '../controllers/announcement_controller.dart';
import '../controllers/announcement_detail_controller.dart';
import '../controllers/home_controller.dart';

HomeRepository _repository() {
  if (Get.isRegistered<HomeRepository>()) {
    return Get.find<HomeRepository>();
  }

  final repository = HomeRepository(
    api: HomeApiService(Get.find<ApiClient>()),
    session: Get.find<SessionRepository>(),
  );

  Get.put<HomeRepository>(repository);

  return repository;
}

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(
      () => HomeController(repository: _repository()),
    );
  }
}

class ActivityBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ActivityController>(
      () => ActivityController(repository: _repository()),
    );
  }
}

class AnnouncementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AnnouncementController>(
      () => AnnouncementController(repository: _repository()),
    );
  }
}

/// The detail screen's own binding.
///
/// The one it replaces was a byte-identical copy of `AnnouncementBinding` and
/// registered `AnnouncementController` — not the detail controller the screen
/// actually uses. The screen worked only because its view called `Get.put`
/// itself (HIGH-06).
class AnnouncementDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AnnouncementDetailController>(
      () => AnnouncementDetailController(repository: _repository()),
    );
  }
}
