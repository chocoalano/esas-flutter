import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/activity_log.dart';
import '../../data/repositories/home_repository.dart';

class ActivityController extends GetxController {
  ActivityController({required HomeRepository repository})
    : _repository = repository;

  final HomeRepository _repository;

  final RxList<ActivityLog> lists = <ActivityLog>[].obs;
  final isLoading = false.obs;
  final isLoadMore = false.obs;
  final hasMore = true.obs;
  final page = 1.obs;

  late final ScrollController scrollController;

  @override
  void onInit() {
    super.onInit();
    scrollController = ScrollController()..addListener(_onScroll);
    resetAndFetch();
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (!scrollController.hasClients || isLoadMore.value || !hasMore.value) {
      return;
    }

    final position = scrollController.position;

    if (position.pixels >= position.maxScrollExtent * 0.9) {
      _loadMore();
    }
  }

  Future<void> resetAndFetch() async {
    page.value = 1;
    hasMore.value = true;
    isLoading.value = true;

    try {
      lists.assignAll(await _repository.recentActivity());
      // The endpoint returns the recent set rather than a page, so there is
      // nothing further to fetch. The old controller incremented a page number
      // against an endpoint that ignored it.
      hasMore.value = false;
    } on ApiException catch (error) {
      showErrorSnackbar('Gagal memuat aktivitas: ${error.message}');
      hasMore.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadMore() async {
    hasMore.value = false;
  }
}
