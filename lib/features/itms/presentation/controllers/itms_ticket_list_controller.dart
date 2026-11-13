import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/itms_ticket.dart';
import '../../data/repositories/itms_repository.dart';

/// All of the requester's tickets, open and finished (FUNC-D04).
///
/// The dashboard shows only what is still open; a ticket used to disappear
/// from the app the moment IT solved it, outcome and all.
class ItmsTicketListController extends GetxController {
  ItmsTicketListController({required ItmsRepository repository})
    : _repository = repository;

  final ItmsRepository _repository;

  /// The rows one page holds — what the API is asked for.
  static const int pageSize = 20;

  final RxList<ItmsTicket> tickets = <ItmsTicket>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final first = await _repository.tickets(page: 1);
      _page = 1;
      tickets.assignAll(first);
      hasMore.value = first.length >= pageSize;
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    try {
      final next = await _repository.tickets(page: _page + 1);
      _page++;
      tickets.addAll(next);
      hasMore.value = next.length >= pageSize;
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoadingMore.value = false;
    }
  }
}
