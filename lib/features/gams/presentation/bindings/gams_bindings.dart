import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/gams_repository.dart';
import '../../data/services/gams_api_service.dart';
import '../controllers/gams_dashboard_controller.dart';

GamsRepository _gamsRepository() {
  if (Get.isRegistered<GamsRepository>()) {
    return Get.find<GamsRepository>();
  }

  final repo = GamsRepository(GamsApiService(Get.find<ApiClient>()));
  Get.put<GamsRepository>(repo);
  return repo;
}

class GamsDashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GamsDashboardController>(
      () => GamsDashboardController(repository: _gamsRepository()),
    );
  }
}

