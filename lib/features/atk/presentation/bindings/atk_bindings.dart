import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/atk_repository.dart';
import '../controllers/atk_desk_detail_controller.dart';
import '../controllers/atk_desk_list_controller.dart';
import '../controllers/atk_request_create_controller.dart';
import '../controllers/atk_request_detail_controller.dart';
import '../controllers/atk_request_list_controller.dart';

AtkRepository _repository() {
  if (Get.isRegistered<AtkRepository>()) {
    return Get.find<AtkRepository>();
  }
  final repo = AtkRepository(Get.find<ApiClient>());
  Get.put<AtkRepository>(repo);
  return repo;
}

/// The route argument: an id, as an int or its string.
int _idArgument() {
  final id = Get.arguments;
  return id is int ? id : int.tryParse('$id') ?? 0;
}

class AtkRequestListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AtkRequestListController>(
      () => AtkRequestListController(repository: _repository()),
    );
  }
}

class AtkRequestCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AtkRequestCreateController>(
      () => AtkRequestCreateController(repository: _repository()),
    );
  }
}

/// The request id is the route argument.
class AtkRequestDetailBinding extends Bindings {
  @override
  void dependencies() {
    final id = _idArgument();
    Get.lazyPut<AtkRequestDetailController>(
      () =>
          AtkRequestDetailController(repository: _repository(), requestId: id),
    );
  }
}

class AtkDeskListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AtkDeskListController>(
      () => AtkDeskListController(repository: _repository()),
    );
  }
}

/// The request id is the route argument.
class AtkDeskDetailBinding extends Bindings {
  @override
  void dependencies() {
    final id = _idArgument();
    Get.lazyPut<AtkDeskDetailController>(
      () => AtkDeskDetailController(repository: _repository(), requestId: id),
    );
  }
}
