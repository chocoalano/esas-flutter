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

  Future<void> resetAndFetch() async {
    page.value = 1;
    hasMore.value = true;
    isLoading.value = true;

    try {
      permits.assignAll(await _fetch());
    } finally {
      isLoading.value = false;
    }
  }

  void loadMorePermits() => _loadMore();

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
        permits.addAll(rows);
      }
    } finally {
      isLoadMore.value = false;
    }
  }

  Future<List<Permit>> _fetch() async {
    final typeId = permitType.value?.id;

    if (typeId == null) {
      hasMore.value = false;
      return const [];
    }

    try {
      final rows = await _repository.list(
        typeId: typeId,
        page: page.value,
        perPage: pageSize,
      );

      hasMore.value = rows.length == pageSize;

      return rows;
    } on ApiException catch (error) {
      hasMore.value = false;
      showErrorSnackbar('Gagal memuat perizinan: ${error.message}');

      return const [];
    }
  }
}
