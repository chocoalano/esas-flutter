import 'package:get/get.dart';

import '../../../../core/tenancy/tenant_context.dart';

import '../../../../core/network/api_client.dart';
import '../../../../features/auth/data/repositories/auth_repository.dart';
import '../../../../features/auth/data/repositories/session_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/profile_api_service.dart';
import '../controllers/profile_bug_report_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/profile_tab_controllers.dart';

/// One repository across the profile tabs, so the five that used to fetch the
/// same user object independently now share a single cached read.
ProfileRepository _repository() {
  if (Get.isRegistered<ProfileRepository>()) {
    return Get.find<ProfileRepository>();
  }

  final repository = ProfileRepository(
    api: ProfileApiService(Get.find<ApiClient>()),
    session: Get.find<SessionRepository>(),
  );

  Get.put<ProfileRepository>(repository);

  return repository;
}

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileController>(
      () => ProfileController(
        repository: _repository(),
        auth: Get.find<AuthRepository>(),
        tenantContext: Get.find<TenantContext>(),
      ),
    );
  }
}

class ProfilePersonalBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<ProfilePersonalController>(
    () => ProfilePersonalController(repository: _repository()),
  );
}

class ProfileWorkedBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<ProfileWorkedController>(
    () => ProfileWorkedController(repository: _repository()),
  );
}

class ProfileFamilyBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<ProfileFamilyController>(
    () => ProfileFamilyController(repository: _repository()),
  );
}

class ProfileEducationBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<ProfileEducationController>(
    () => ProfileEducationController(repository: _repository()),
  );
}

class ProfileExperienceBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<ProfileExperienceController>(
    () => ProfileExperienceController(repository: _repository()),
  );
}

class ProfilePayrollBinding extends Bindings {
  @override
  void dependencies() =>
      Get.lazyPut<ProfilePayrollController>(ProfilePayrollController.new);
}

class ProfileBugReportBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<ProfileBugReportController>(
    () => ProfileBugReportController(repository: _repository()),
  );
}
