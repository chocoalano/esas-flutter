import 'package:get/get.dart';

import '../../../../core/config/server_config.dart';
import '../../../../core/tenancy/tenant_context.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/workspace_repository.dart';
import '../controllers/setup_controller.dart';

/// `ServerConfig` and `TenantContext` are application-wide and come from
/// `InitialBinding`; this binding registers the screen's own controller and the
/// repository under it, and nothing else (HIGH-07).
class SetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SetupController>(
      () => SetupController(
        repository: WorkspaceRepository(
          serverConfig: Get.find<ServerConfig>(),
          tenantContext: Get.find<TenantContext>(),
        ),
        // The same way out "Pindah workspace" on the profile takes.
        endSession: () async {
          if (!Get.isRegistered<AuthRepository>()) return;
          final auth = Get.find<AuthRepository>();
          if (auth.isAuthenticated) await auth.logout();
        },
      ),
    );
  }
}
