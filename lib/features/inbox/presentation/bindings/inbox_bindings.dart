import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/inbox_repository.dart';
import '../../data/services/inbox_api_service.dart';
import '../controllers/unified_inbox_controller.dart';

class UnifiedInboxBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UnifiedInboxController>(
      () => UnifiedInboxController(
        repository: InboxRepository(InboxApiService(Get.find<ApiClient>())),
      ),
    );
  }
}
