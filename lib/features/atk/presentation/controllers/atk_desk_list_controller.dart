import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/atk_models.dart';
import '../../data/repositories/atk_repository.dart';

/// "Meja ATK": the open ATK requests a GA officer works through.
///
/// The server decides who is a GA officer. Anyone else is answered 403
/// (`DESK_NOT_ALLOWED`), which this screen reads as "no access" rather than as
/// a failure worth retrying.
class AtkDeskListController extends GetxController {
  AtkDeskListController({required AtkRepository repository})
    : _repository = repository;

  final AtkRepository _repository;

  final RxList<AtkDeskRequest> requests = <AtkDeskRequest>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();
  final RxnString loadMoreError = RxnString();

  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// The account may not use the desk at all.
  bool get isDenied =>
      error.value?.isForbidden == true ||
      error.value?.code == 'DESK_NOT_ALLOWED';

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    loadMoreError.value = null;
    try {
      final first = await _repository.desk();
      _page = 1;
      requests.assignAll(first.items);
      hasMore.value = first.lastPage > _page;
    } on ApiException catch (e) {
      error.value = e;
      if (e.isForbidden) requests.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    loadMoreError.value = null;
    try {
      final next = await _repository.desk(page: _page + 1);
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
