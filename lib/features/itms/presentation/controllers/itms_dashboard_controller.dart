import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/itms_knowledge_article.dart';
import '../../data/models/itms_service.dart';
import '../../data/models/itms_ticket.dart';
import '../../data/repositories/itms_repository.dart';

class ItmsDashboardController extends GetxController {
  ItmsDashboardController({required ItmsRepository repository})
    : _repository = repository;

  final ItmsRepository _repository;

  final isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  final RxList<ItmsTicket> tickets = <ItmsTicket>[].obs;
  final RxList<ItmsService> services = <ItmsService>[].obs;
  final RxList<ItmsKnowledgeArticle> articles = <ItmsKnowledgeArticle>[].obs;

  /// Why a section could not be loaded, by section key.
  final RxMap<String, ApiException> sectionErrors =
      <String, ApiException>{}.obs;

  /// The rows one page of tickets holds — what the API is asked for.
  static const int pageSize = 20;

  /// Tickets still waiting on somebody (ITMS-01). "Aktif" used to count the
  /// resolved and closed ones too.
  List<ItmsTicket> get activeTickets =>
      tickets.where((ticket) => !ticket.isClosed).toList();

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  /// Load all three sections in parallel, each failing on its own.
  ///
  /// The sequential version meant a 404 on tickets hid the service catalog
  /// and the knowledge base too — the most common failure on a first deploy
  /// where ticket history is empty but services are configured.
  Future<void> loadDashboard() async {
    isLoading.value = true;
    error.value = null;
    sectionErrors.clear();

    Future<void> section<T>(
      String key,
      Future<List<T>> Function() load,
      RxList<T> into,
    ) async {
      try {
        into.assignAll(await load());
      } on ApiException catch (e) {
        sectionErrors[key] = e;
      } catch (e) {
        sectionErrors[key] = ApiException(e.toString());
      }
    }

    try {
      await Future.wait([
        section('tickets', _repository.tickets, tickets),
        section('services', _repository.services, services),
        section('articles', _repository.knowledgeArticles, articles),
      ]);

      if (sectionErrors.length == 3) {
        error.value = sectionErrors.values.first;
      }
    } finally {
      isLoading.value = false;
    }
  }
}
