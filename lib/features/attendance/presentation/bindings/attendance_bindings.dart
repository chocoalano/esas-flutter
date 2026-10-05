import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/tenancy/tenant_context.dart';
import '../../../../features/auth/data/repositories/session_repository.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/services/attendance_api_service.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/attendance_list_controller.dart';

/// The feature's own dependencies, scoped to its routes.
///
/// The repository is looked up before it is built so a test can put a double in
/// front of the route and drive the real binding, the real controller and the
/// real view — the seam `attendance_production_tree_test.dart` uses. Nothing
/// here is `permanent`: a capture screen and a paginated list have no business
/// outliving their routes (rule §10), and on this screen that rule is also a
/// privacy one — the controller's `onClose` is what hands the camera back.
AttendanceRepository _repository() {
  if (Get.isRegistered<AttendanceRepository>()) {
    return Get.find<AttendanceRepository>();
  }

  final repository = AttendanceRepository(
    api: AttendanceApiService(Get.find<ApiClient>()),
    session: Get.find<SessionRepository>(),
    tenant: Get.find<TenantContext>(),
  );

  Get.put<AttendanceRepository>(repository);

  return repository;
}

class AttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AttendanceController>(
      () => AttendanceController(
        repository: _repository(),
        location: const LocationService(),
        session: Get.find<SessionRepository>(),
        storage: Get.find<LocalStorage>(),
      ),
    );
  }
}

class AttendanceListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AttendanceListController>(
      () => AttendanceListController(repository: _repository()),
    );
  }
}
