import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../data/models/field_task.dart';
import '../../data/models/task_action.dart';
import '../../data/repositories/tasks_repository.dart';
import 'my_tasks_controller.dart';

/// One task, and the actions the worker takes on it.
///
/// **One logical action, one Idempotency-Key.** The key is minted the first
/// time an action with a given body is sent and reused for every retry of
/// that same action - including after a timeout, when the app cannot know
/// whether the server acted. A changed body is a new action and gets a new
/// key. The key is dropped once the server has given a definite answer.
class TaskDetailController extends GetxController with WidgetsBindingObserver {
  TaskDetailController({
    required TasksRepository repository,
    required this.domain,
    required this.id,
  }) : _repository = repository;

  final TasksRepository _repository;
  final TaskDomain domain;
  final int id;

  final Rxn<FieldTaskDetail> detail = Rxn<FieldTaskDetail>();
  final isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  /// The action being sent, so its button shows progress and no second
  /// action starts meanwhile.
  final RxnString submitting = RxnString();

  /// What the last action ended in, when it did not simply succeed.
  final RxnString notice = RxnString();
  final RxBool noticeIsConflict = false.obs;

  final Map<String, String> _attemptKeys = {};

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// Back from the background: a supervisor may have reassigned, cancelled or
  /// sent the work back meanwhile (FUNC-D12). Never mid-action.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && submitting.value == null) {
      load();
    }
  }

  Future<void> load() async {
    isLoading.value = detail.value == null;
    error.value = null;
    try {
      detail.value = await _repository.detail(domain, id);
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoading.value = false;
    }
  }

  List<TaskAction> get actions {
    final current = detail.value;
    return current == null ? const [] : TaskAction.forTask(current.task);
  }

  bool get canCompleteSteps =>
      detail.value?.task.allowedActions.contains('complete_task') ?? false;

  /// Send [action] (or, with [stepId], tick that step). Returns whether the
  /// server applied it.
  Future<bool> run(TaskAction action, {String? input, int? stepId}) async {
    final current = detail.value;
    if (current == null || submitting.value != null) return false;

    final path = stepId == null ? action.path : 'tasks/$stepId/complete';
    final body = <String, dynamic>{
      if (action.needsInput && stepId == null)
        action.inputField!: input?.trim() ?? '',
      // GAMS and ITMS refuse a stale screen with 409 instead of overwriting.
      if (domain != TaskDomain.mtms && current.task.lockVersion != null)
        'lock_version': current.task.lockVersion,
    };
    final signature = '$path|${jsonEncode(body)}';
    final key = _attemptKeys.putIfAbsent(signature, IdempotencyKey.mint);

    submitting.value = stepId == null ? action.key : 'step:$stepId';
    notice.value = null;
    noticeIsConflict.value = false;

    try {
      detail.value = await _repository.act(
        domain,
        id,
        path,
        body,
        idempotencyKey: key,
      );
      _attemptKeys.remove(signature);
      _refreshList();
      return true;
    } on ApiException catch (e) {
      await _settleFailure(e, signature);
      return false;
    } finally {
      submitting.value = null;
    }
  }

  Future<void> _settleFailure(ApiException e, String signature) async {
    // No answer, or a server fault: the action may or may not have happened.
    // Keep the key, so sending again cannot act twice, and read the task back
    // to see where it stands.
    if (e.isTransportFailure || (e.status ?? 0) >= 500) {
      notice.value =
          'Hasil belum pasti karena koneksi terputus. Status tugas dimuat ulang; '
          'bila belum berubah, kirim ulang - sistem tidak akan mencatatnya dua kali.';
      await load();
      return;
    }

    if (e.code == 'idempotency_in_progress') {
      notice.value = 'Permintaan yang sama masih diproses. Coba lagi sebentar.';
      return;
    }

    _attemptKeys.remove(signature);

    if (e.status == 409) {
      noticeIsConflict.value = true;
      notice.value =
          'Status tugas sudah berubah di server. Data terbaru dimuat ulang.';
      await load();
      return;
    }

    if (e.status == 404) {
      error.value = e;
      return;
    }

    notice.value = e.isForbidden
        ? 'Anda tidak berhak melakukan tindakan ini.'
        : e.message;

    if (e.isForbidden) {
      await load();
    }
  }

  void _refreshList() {
    if (Get.isRegistered<MyTasksController>()) {
      Get.find<MyTasksController>().load();
    }
  }
}
