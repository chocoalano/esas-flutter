import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/itms_repository.dart';
import '../../data/services/itms_api_service.dart';
import '../controllers/itms_dashboard_controller.dart';
import '../controllers/itms_ticket_create_controller.dart';
import '../controllers/itms_ticket_detail_controller.dart';
import '../controllers/itms_ticket_list_controller.dart';

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

class ItmsTicketCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ItmsTicketCreateController>(
      () => ItmsTicketCreateController(repository: _itmsRepository()),
    );
  }
}

class ItmsTicketListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ItmsTicketListController>(
      () => ItmsTicketListController(repository: _itmsRepository()),
    );
  }
}

/// The ticket id is the route argument.
class ItmsTicketDetailBinding extends Bindings {
  @override
  void dependencies() {
    final id = Get.arguments;
    Get.lazyPut<ItmsTicketDetailController>(
      () => ItmsTicketDetailController(
        repository: _itmsRepository(),
        ticketId: id is int ? id : int.tryParse('$id') ?? 0,
      ),
    );
  }
}
