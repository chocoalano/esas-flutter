import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/announcement.dart';
import '../../data/repositories/home_repository.dart';

class AnnouncementController extends GetxController {
  AnnouncementController({required HomeRepository repository})
    : _repository = repository;

  final HomeRepository _repository;

  final RxList<Announcement> lists = <Announcement>[].obs;
  final isLoading = false.obs;
  final isLoadMore = false.obs;
  final hasMore = true.obs;
  final page = 1.obs;

  static const int _perPage = 10;

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

  /// Why the last load failed, or null — not an empty list (HOME-15).
  final Rxn<ApiException> loadError = Rxn<ApiException>();

  /// Bumped by every reset; an answer to an older one is dropped (HOME-16).
  int _generation = 0;

  void _onScroll() {
    if (!scrollController.hasClients ||
        isLoadMore.value ||
        !hasMore.value ||
        loadError.value != null) {
      return;
    }

    final position = scrollController.position;

    if (position.pixels >= position.maxScrollExtent * 0.9) {
      loadMore();
    }
  }

  Future<void> resetAndFetch() async {
    final generation = ++_generation;

    page.value = 1;
    hasMore.value = true;
    isLoading.value = true;

    try {
      final rows = await _fetch(1);
      if (generation != _generation) return;

      hasMore.value = rows.length == _perPage;
      lists.assignAll(rows);
      loadError.value = null;
    } on ApiException catch (error) {
      if (generation != _generation) return;

      // What was on screen stays, and the failure is said (HOME-15).
      loadError.value = error;
      showErrorSnackbar('Gagal memuat pengumuman: ${error.message}');
    } finally {
      if (generation == _generation) isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadMore.value || !hasMore.value || isLoading.value) {
      return;
    }

    final generation = _generation;
    final next = page.value + 1;

    isLoadMore.value = true;

    try {
      final rows = await _fetch(next);
      // A page from before a refresh belongs to a list that no longer exists
      // (HOME-16).
      if (generation != _generation) return;

      // Set after the generation check, not inside `_fetch`: a stale page
      // answering after a refresh switched paging off (UAT review H6).
      hasMore.value = rows.length == _perPage;

      if (rows.isNotEmpty) {
        page.value = next;
        lists.addAll(rows);
      }
    } on ApiException catch (error) {
      // A failed page is retried by the next scroll; paging is not switched
      // off for good over a dropped connection (HOME-15).
      if (generation == _generation) {
        showErrorSnackbar('Gagal memuat pengumuman: ${error.message}');
      }
    } finally {
      isLoadMore.value = false;
    }
  }

  /// One page. Throws [ApiException].
  Future<List<Announcement>> _fetch(int pageNumber) async {
    final rows = await _repository.announcements(
      page: pageNumber,
      perPage: _perPage,
    );

    return rows;
  }
}
