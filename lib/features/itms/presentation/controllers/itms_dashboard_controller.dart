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

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    isLoading.value = true;
    error.value = null;

    try {
      final t = await _repository.tickets();
      tickets.assignAll(t);

      final s = await _repository.services();
      services.assignAll(s);

      final a = await _repository.knowledgeArticles();
      articles.assignAll(a);
    } on ApiException catch (e) {
      error.value = e;
    } catch (e) {
      error.value = ApiException(e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}

