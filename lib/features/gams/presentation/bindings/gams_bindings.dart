import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/gams_repository.dart';
import '../../data/services/gams_api_service.dart';
import '../controllers/gams_create_controller.dart';
import '../controllers/gams_dashboard_controller.dart';
import '../controllers/gams_request_tracking_controllers.dart';

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

/// The binding of one GAMS form (GAMS-01), tagged by its kind so the four
/// forms never share a controller.
class GamsCreateBinding extends Bindings {
  GamsCreateBinding(this.kind);

  final GamsCreateKind kind;

  @override
  void dependencies() {
    Get.lazyPut<GamsCreateController>(
      () => GamsCreateController(repository: _gamsRepository(), kind: kind),
      tag: kind.name,
    );
  }
}

class GamsRequestListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GamsRequestListController>(
      () => GamsRequestListController(repository: _gamsRepository()),
    );
  }
}

/// The request id is the route argument.
class GamsRequestDetailBinding extends Bindings {
  @override
  void dependencies() {
    final id = Get.arguments;
    Get.lazyPut<GamsRequestDetailController>(
      () => GamsRequestDetailController(
        repository: _gamsRepository(),
        requestId: id is int ? id : int.tryParse('$id') ?? 0,
      ),
    );
  }
}
