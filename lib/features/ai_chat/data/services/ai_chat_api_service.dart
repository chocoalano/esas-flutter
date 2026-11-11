import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/idempotency_key.dart';

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

  /// Start a conversation with its first message.
  ///
  /// [idempotencyKey] names this one question (AI-02). Sending it again with
  /// the same key after a reply that never arrived gets the server's original
  /// answer back — including the conversation it opened — instead of a second
  /// conversation and a second answer.
  Future<Map<String, dynamic>> startConversation(
    String message, {
    String? idempotencyKey,
  }) => _client.postObject(
    ApiRoutes.aiChatConversations,
    {'message': message},
    headers: IdempotencyKey.headerFor(idempotencyKey),
    awaitsModel: true,
  );

  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String message, {
    String? idempotencyKey,
  }) => _client.postObject(
    ApiRoutes.aiChatMessages(conversationId),
    {'message': message},
    headers: IdempotencyKey.headerFor(idempotencyKey),
    awaitsModel: true,
  );

  Future<void> deleteConversation(String id) =>
      _client.deleteObject(ApiRoutes.aiChatConversation(id));
}
