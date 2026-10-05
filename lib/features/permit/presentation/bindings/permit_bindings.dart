import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../../../features/auth/data/repositories/session_repository.dart';
import '../../data/repositories/permit_repository.dart';
import '../../data/services/permit_api_service.dart';
import '../controllers/permit_controller.dart';
import '../controllers/permit_create_controller.dart';
import '../controllers/permit_list_controller.dart';
import '../controllers/permit_show_controller.dart';

PermitRepository _repository() {
  if (Get.isRegistered<PermitRepository>()) {
    return Get.find<PermitRepository>();
  }

  final repository = PermitRepository(
    api: PermitApiService(Get.find<ApiClient>()),
    session: Get.find<SessionRepository>(),
  );

  Get.put<PermitRepository>(repository);

  return repository;
}

class PermitBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<PermitController>(
    () => PermitController(repository: _repository()),
  );
}

class PermitListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PermitListController>(
      () => PermitListController(repository: _repository()),
    );
    // `PermitCreateController` used to be registered here as well, which is how
    // the create screen worked at all — see PermitCreateBinding.
  }
}

class PermitShowBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<PermitShowController>(
    () => PermitShowController(repository: _repository()),
  );
}

/// The create screen's own binding — HIGH-01.
///
/// `/permit/create` was wired to `PermitShowBinding`, which registers
/// `PermitShowController` and nothing else. The screen only worked by accident:
/// `PermitListBinding` registered `PermitCreateController`, and navigating
/// list → create with `Get.toNamed` keeps the list route alive, so the instance
/// was still in the registry when `PermitCreate` asked for it.
///
/// Any other way in — a deep link, a notification tap, a future
/// `Get.offAllNamed('/permit/create')` — threw "PermitCreateController not
/// found" and showed a red screen. It also constructed a `PermitShowController`
/// on every visit to a screen that never used one.
class PermitCreateBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<PermitCreateController>(
    () => PermitCreateController(repository: _repository()),
  );
}
