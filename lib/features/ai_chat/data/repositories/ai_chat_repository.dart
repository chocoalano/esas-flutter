import '../../../../core/utils/json_parsers.dart';
import '../models/ai_chat_context.dart';
import '../models/ai_chat_conversation.dart';
import '../models/ai_chat_reply.dart';
import '../services/ai_chat_api_service.dart';

class AiChatRepository {
  const AiChatRepository(this._api);

  final AiChatApiService _api;

  Future<AiChatContext> context() async {
    final response = await _api.context();
    return AiChatContext.fromJson(response);
  }

  Future<List<AiChatConversation>> conversations({int page = 1}) async {
    final response = await _api.conversations(page: page);
    final data = asList(response['data']);
    return data
        .map((item) => AiChatConversation.fromJson(asObject(item)))
        .toList();
  }

  Future<AiChatConversation> conversation(String id) async {
    final response = await _api.conversation(id);
    return AiChatConversation.fromJson(asObject(response['data']));
  }

  Future<AiChatReply> startConversation(
    String message, {
    String? idempotencyKey,
  }) async {
    final response = await _api.startConversation(
      message,
      idempotencyKey: idempotencyKey,
    );
    return AiChatReply.fromJson(response);
  }

  Future<AiChatReply> sendMessage(
    String conversationId,
    String message, {
    String? idempotencyKey,
  }) async {
    final response = await _api.sendMessage(
      conversationId,
      message,
      idempotencyKey: idempotencyKey,
    );
    return AiChatReply.fromJson(response);
  }

  Future<void> deleteConversation(String id) => _api.deleteConversation(id);
}
