import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/atk_models.dart';
import '../../data/repositories/atk_repository.dart';

/// "Permintaan ATK Saya": every ATK request the employee filed, newest first.
class AtkRequestListController extends GetxController {
  AtkRequestListController({required AtkRepository repository})
    : _repository = repository;

  final AtkRepository _repository;

  final RxList<AtkRequest> requests = <AtkRequest>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  /// A later page that failed while the first is on screen. Shown beside the
  /// load-more button rather than replacing the list.
  final RxnString loadMoreError = RxnString();

  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    loadMoreError.value = null;
    try {
      final first = await _repository.requests();
      _page = 1;
      requests.assignAll(first.items);
      hasMore.value = first.lastPage > _page;
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    loadMoreError.value = null;
    try {
      final next = await _repository.requests(page: _page + 1);
      _page++;
      requests.addAll(next.items);
      hasMore.value = next.lastPage > _page;
    } on ApiException catch (e) {
      loadMoreError.value = e.message;
    } finally {
      isLoadingMore.value = false;
    }
  }
}
