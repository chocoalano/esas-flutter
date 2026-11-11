import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';

class AiChatApiService {
  const AiChatApiService(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> context() =>
      _client.getObject(ApiRoutes.aiChatContext);

  Future<Map<String, dynamic>> conversations({int page = 1}) =>
      _client.getObject(
        ApiRoutes.aiChatConversations,
        query: {'page': page, 'per_page': 20},
      );

  Future<Map<String, dynamic>> conversation(String id) =>
      _client.getObject(ApiRoutes.aiChatConversation(id));

  Future<Map<String, dynamic>> startConversation(String message) =>
      _client.postObject(
        ApiRoutes.aiChatConversations,
        {'message': message},
      );

  Future<Map<String, dynamic>> sendMessage(String conversationId, String message) =>
      _client.postObject(
        ApiRoutes.aiChatMessages(conversationId),
        {'message': message},
      );

  Future<void> deleteConversation(String id) =>
      _client.deleteObject(ApiRoutes.aiChatConversation(id));
}

