import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/tenancy/tenant_context.dart';
import '../../data/repositories/device_proof_gate.dart';
import '../../data/repositories/device_proof_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/device_auth_api_service.dart';
import '../../data/services/device_key_service.dart';
import '../controllers/device_enrollment_controller.dart';

/// The device repository, built on first use and kept for the app's life.
///
/// Looked up before it is built, so a test can put a double in front of a
/// route — the seam `attendance_bindings.dart` uses. Null when the app-wide
/// network and session are not there (a widget test of another screen), which
/// callers read as "no device gate": attendance as it has always been.
DeviceProofRepository? findDeviceProofRepository() {
  if (Get.isRegistered<DeviceProofRepository>()) {
    return Get.find<DeviceProofRepository>();
  }

  if (!Get.isRegistered<ApiClient>() ||
      !Get.isRegistered<SessionRepository>()) {
    return null;
  }

  return Get.put<DeviceProofRepository>(
    DeviceProofRepository(
      api: DeviceAuthApiService(Get.find<ApiClient>()),
      keys: DeviceKeyService(),
      session: Get.find<SessionRepository>(),
      // Read per call: the key belongs to the account in the workspace the
      // app is signed in to NOW, and a switch must reach a different key.
      workspace: () => Get.isRegistered<TenantContext>()
          ? Get.find<TenantContext>().tenant
          : null,
    ),
    permanent: true,
  );
}

/// The attendance-entry gate. Session-wide, because the retry budget and the
/// in-flight proof must be shared by every way into attendance.
DeviceProofGate? findDeviceProofGate() {
  if (Get.isRegistered<DeviceProofGate>()) {
    return Get.find<DeviceProofGate>();
  }

  final repository = findDeviceProofRepository();

  if (repository == null) return null;

  return Get.put<DeviceProofGate>(
    DeviceProofGate(repository: repository),
    permanent: true,
  );
}

class DeviceEnrollmentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DeviceEnrollmentController>(
      () =>
          DeviceEnrollmentController(repository: findDeviceProofRepository()!),
    );
  }
}
