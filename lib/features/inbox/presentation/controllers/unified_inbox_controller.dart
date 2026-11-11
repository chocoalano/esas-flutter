import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/approval_task.dart';
import '../../data/repositories/inbox_repository.dart';

class UnifiedInboxController extends GetxController {
  UnifiedInboxController({required InboxRepository repository})
      : _repository = repository;

  final InboxRepository _repository;

  final isLoading = true.obs;
  final isDeciding = false.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();
  final RxList<ApprovalTask> tasks = <ApprovalTask>[].obs;
  final RxString selectedFilter = 'all'.obs;

  @override
  void onInit() {
    super.onInit();
    loadTasks();
  }

  Future<void> loadTasks() async {
    isLoading.value = true;
    error.value = null;

    try {
      final result = await _repository.tasks();
      tasks.assignAll(result);
    } on ApiException catch (e) {
      error.value = e;
    } catch (e) {
      error.value = ApiException(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> decideTask({
    required String taskId,
    required String decision,
    String? note,
  }) async {
    isDeciding.value = true;
    try {
      await _repository.decideTask(
        taskId: taskId,
        decision: decision,
        note: note,
      );
      tasks.removeWhere((t) => t.id == taskId);
      Get.snackbar(
        'Berhasil',
        decision == 'approved'
            ? 'Pengajuan berhasil disetujui.'
            : 'Pengajuan telah ditolak.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Gagal', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (e) {
      Get.snackbar('Gagal', e.toString(), snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isDeciding.value = false;
    }
  }

  List<ApprovalTask> get filteredTasks {
    if (selectedFilter.value == 'all') {
      return tasks;
    }
    return tasks.where((t) => t.domain == selectedFilter.value).toList();
  }
}

