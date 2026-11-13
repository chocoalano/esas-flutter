import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/idempotency_key.dart';

class ItmsApiService {
  const ItmsApiService(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> services() =>
      _client.getObject(ApiRoutes.itmsServices);

  Future<Map<String, dynamic>> tickets({int page = 1}) => _client.getObject(
    ApiRoutes.itmsTickets,
    query: {'page': page, 'per_page': 20},
  );

  Future<Map<String, dynamic>> ticket(int id) =>
      _client.getObject(ApiRoutes.itmsTicket(id));

  Future<Map<String, dynamic>> createTicket({
    required int serviceId,
    required String subject,
    String? description,
    String? idempotencyKey,
  }) => _client.postObject(ApiRoutes.itmsTickets, {
    'service_id': serviceId,
    'subject': subject,
    if (description != null) 'description': description,
  }, headers: IdempotencyKey.headerFor(idempotencyKey));

  Future<Map<String, dynamic>> knowledgeArticles({
    String? query,
    int page = 1,
  }) => _client.getObject(
    ApiRoutes.itmsKnowledgeArticles,
    query: {
      if (query != null && query.isNotEmpty) 'q': query,
      'page': page,
      'per_page': 20,
    },
  );

  Future<Map<String, dynamic>> knowledgeArticle(int id) =>
      _client.getObject(ApiRoutes.itmsKnowledgeArticle(id));

  Future<Map<String, dynamic>> myAssets({int page = 1}) => _client.getObject(
    ApiRoutes.itmsMyAssets,
    query: {'page': page, 'per_page': 20},
  );

  Future<Map<String, dynamic>> acknowledgeAsset(int id) =>
      _client.postObject(ApiRoutes.itmsAcknowledgeAsset(id), const {});
}
