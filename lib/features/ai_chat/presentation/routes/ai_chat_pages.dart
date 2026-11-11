import 'package:get/get.dart';

import '../bindings/ai_chat_bindings.dart';
import '../views/ai_chat_view.dart';
import 'ai_chat_routes.dart';

class AiChatPages {
  const AiChatPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: AiChatRoutes.chat,
      page: () => const AiChatView(),
      binding: AiChatBinding(),
      transition: Transition.noTransition,
    ),
  ];
}
