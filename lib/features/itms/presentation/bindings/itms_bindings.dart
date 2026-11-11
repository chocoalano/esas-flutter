import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/itms_repository.dart';
import '../../data/services/itms_api_service.dart';
import '../controllers/itms_dashboard_controller.dart';

ItmsRepository _itmsRepository() {
  if (Get.isRegistered<ItmsRepository>()) {
    return Get.find<ItmsRepository>();
  }

  final repo = ItmsRepository(ItmsApiService(Get.find<ApiClient>()));
  Get.put<ItmsRepository>(repo);
  return repo;
}

class ItmsDashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ItmsDashboardController>(
      () => ItmsDashboardController(repository: _itmsRepository()),
    );
  }
}

