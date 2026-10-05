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
      lists.assignAll(await _fetch());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadMore() async {
    if (isLoadMore.value || !hasMore.value) {
      return;
    }

    isLoadMore.value = true;
    page.value += 1;

    try {
      final rows = await _fetch();

      if (rows.isEmpty) {
        page.value -= 1;
      } else {
        lists.addAll(rows);
      }
    } finally {
      isLoadMore.value = false;
    }
  }

  Future<List<Announcement>> _fetch() async {
    try {
      final rows = await _repository.announcements(
        page: page.value,
        perPage: _perPage,
      );

      hasMore.value = rows.length == _perPage;

      return rows;
    } on ApiException catch (error) {
      hasMore.value = false;
      showErrorSnackbar('Gagal memuat pengumuman: ${error.message}');

      return const [];
    }
  }
}
