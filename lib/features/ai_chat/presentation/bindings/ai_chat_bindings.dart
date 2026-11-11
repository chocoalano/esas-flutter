import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/ai_chat_repository.dart';
import '../../data/services/ai_chat_api_service.dart';
import '../controllers/ai_chat_controller.dart';

class AiChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AiChatController>(
      () => AiChatController(
        repository: AiChatRepository(
          AiChatApiService(Get.find<ApiClient>()),
        ),
      ),
    );
  }
}

