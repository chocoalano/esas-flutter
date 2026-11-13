import '../../../../core/utils/json_parsers.dart';
import '../models/itms_asset.dart';
import '../models/itms_knowledge_article.dart';
import '../models/itms_service.dart';
import '../models/itms_ticket.dart';
import '../services/itms_api_service.dart';

class ItmsRepository {
  const ItmsRepository(this._api);

  final ItmsApiService _api;

  Future<List<ItmsService>> services() async {
    final response = await _api.services();
    final data = asList(response['data']);
    return data.map((item) => ItmsService.fromJson(asObject(item))).toList();
  }

  Future<List<ItmsTicket>> tickets({int page = 1}) async {
    final response = await _api.tickets(page: page);
    final data = asList(response['data']);
    return data.map((item) => ItmsTicket.fromJson(asObject(item))).toList();
  }

  Future<ItmsTicket> ticket(int id) async {
    final response = await _api.ticket(id);
    return ItmsTicket.fromJson(asObject(response['data']));
  }

  Future<void> createTicket({
    required int serviceId,
    required String subject,
    String? description,
    String? idempotencyKey,
  }) => _api.createTicket(
    serviceId: serviceId,
    subject: subject,
    description: description,
    idempotencyKey: idempotencyKey,
  );

  Future<List<ItmsKnowledgeArticle>> knowledgeArticles({
    String? query,
    int page = 1,
  }) async {
    final response = await _api.knowledgeArticles(query: query, page: page);
    final data = asList(response['data']);
    return data
        .map((item) => ItmsKnowledgeArticle.fromJson(asObject(item)))
        .toList();
  }

  Future<ItmsKnowledgeArticle> knowledgeArticle(int id) async {
    final response = await _api.knowledgeArticle(id);
    return ItmsKnowledgeArticle.fromJson(asObject(response['data']));
  }

  Future<List<ItmsAsset>> myAssets({int page = 1}) async {
    final response = await _api.myAssets(page: page);
    final data = asList(response['data']);
    return data.map((item) => ItmsAsset.fromJson(asObject(item))).toList();
  }

  Future<void> acknowledgeAsset(int id) => _api.acknowledgeAsset(id);
}
