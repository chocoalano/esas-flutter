import 'package:get/get.dart';

import '../../../../core/config/server_config.dart';
import '../../../../core/services/device_info_service.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/tenancy/tenant_context.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/auth_api_service.dart';
import '../controllers/change_password_controller.dart';
import '../controllers/login_controller.dart';
import '../controllers/splash_controller.dart';

/// Feature bindings register feature controllers. `AuthRepository`,
/// `SessionRepository` and `AuthApiService` are application-wide and come from
/// `InitialBinding` — a feature binding registering infrastructure is exactly
/// what produced four live `ApiProvider` instances (HIGH-07).
class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SplashController>(
      () => SplashController(
        authRepository: Get.find<AuthRepository>(),
        localStorage: Get.find<LocalStorage>(),
        serverConfig: Get.find<ServerConfig>(),
        tenantContext: Get.find<TenantContext>(),
      ),
    );
  }
}

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoginController>(
      () => LoginController(
        authRepository: Get.find<AuthRepository>(),
        deviceInfo: Get.find<DeviceInfoService>(),
      ),
    );
  }
}

class ChangePasswordBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChangePasswordController>(
      () => ChangePasswordController(api: Get.find<AuthApiService>()),
    );
  }
}
