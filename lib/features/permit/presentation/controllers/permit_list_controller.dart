import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/leave_list.dart';
import '../../data/models/leave_type.dart';
import '../../data/repositories/permit_repository.dart';

class PermitListController extends GetxController {
  PermitListController({required PermitRepository repository})
    : _repository = repository;

  final PermitRepository _repository;

  final isLoading = false.obs;
  final isLoadMore = false.obs;
  final hasMore = true.obs;
  final page = 1.obs;
  final int pageSize = 10;

  final RxList<Permit> permits = <Permit>[].obs;
  final permitType = Rx<LeaveType?>(null);
  final RxString appBarTitle = 'Daftar Perizinan'.obs;

  late final ScrollController scrollController;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments;

    if (args is LeaveType) {
      permitType.value = args;
      appBarTitle.value = 'Daftar ${args.type}';
    }

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

    if (position.pixels >= position.maxScrollExtent) {
      loadMorePermits();
    }
  }

  /// Why the last load failed, or null. Distinct from an empty list
  /// (PRMT-14): an offline refresh used to replace the history with nothing
  /// and call it "Belum ada pengajuan".
  final Rxn<ApiException> loadError = Rxn<ApiException>();

  /// Bumped by every reset, so an answer to an older request is recognised
  /// and dropped (PRMT-15).
  int _generation = 0;

  Future<void> resetAndFetch() async {
    final generation = ++_generation;

    page.value = 1;
    hasMore.value = true;
    isLoading.value = true;

    try {
      final rows = await _fetch(page: 1);
      if (generation != _generation) return;

      hasMore.value = rows.length == pageSize;
      permits.assignAll(rows);
      loadError.value = null;
    } on ApiException catch (error) {
      if (generation != _generation) return;

      // What was on screen stays; the failure is said, not disguised as an
      // empty history.
      loadError.value = error;
      hasMore.value = false;
      showErrorSnackbar('Gagal memuat perizinan: ${error.message}');
    } finally {
      if (generation == _generation) isLoading.value = false;
    }
  }

  Future<void> loadMorePermits() => _loadMore();

  Future<void> _loadMore() async {
    if (isLoadMore.value || !hasMore.value || isLoading.value) {
      return;
    }

    final generation = _generation;
    final next = page.value + 1;

    isLoadMore.value = true;

    try {
      final rows = await _fetch(page: next);

      // A refresh started while this page was on its way: it belongs to a
      // list that no longer exists.
      if (generation != _generation) return;

      // Set here, after the generation check, not inside `_fetch`: a stale
      // page answering after a refresh switched paging off for the new list
      // (UAT review A5).
      hasMore.value = rows.length == pageSize;

      // The page counter moves only once the page has actually arrived, so a
      // failure is retried rather than skipped.
      if (rows.isNotEmpty) {
        page.value = next;
        permits.addAll(rows);
      }
    } on ApiException catch (error) {
      if (generation == _generation) {
        showErrorSnackbar('Gagal memuat perizinan: ${error.message}');
      }
    } finally {
      isLoadMore.value = false;
    }
  }

  /// One page. Throws [ApiException]; the caller decides what a failure means.
  ///
  /// With no type, every request of this person's (PRMT-05). The home screen
  /// opens the list that way, and `GET /permits` without `type` is exactly
  /// that list — this used to answer nothing instead.
  Future<List<Permit>> _fetch({required int page}) async {
    final rows = await _repository.list(
      typeId: permitType.value?.id,
      page: page,
      perPage: pageSize,
    );

    return rows;
  }
}
