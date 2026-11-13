import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/field_task.dart';
import '../../data/repositories/tasks_repository.dart';

/// "Tugas Saya": the work assigned to the signed-in worker in every field
/// domain the workspace has. Each domain is asked of its own API, which
/// already scopes the list to this worker; nothing is filtered out here.
class MyTasksController extends GetxController with WidgetsBindingObserver {
  MyTasksController({
    required TasksRepository repository,
    required List<TaskDomain> domains,
    TaskDomain? initialDomain,
  }) : _repository = repository,
       domains = List.unmodifiable(domains) {
    if (initialDomain != null && domains.contains(initialDomain)) {
      filter.value = initialDomain;
    }
  }

  final TasksRepository _repository;

  /// The field domains this workspace has active.
  final List<TaskDomain> domains;

  final isLoading = true.obs;
  final RxList<FieldTask> tasks = <FieldTask>[].obs;
  final RxMap<TaskDomain, ApiException> failures =
      <TaskDomain, ApiException>{}.obs;
  final Rxn<TaskDomain> filter = Rxn<TaskDomain>();

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

  /// Back from the background: work may have been assigned meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !isLoading.value) {
      load();
    }
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final result = await _repository.myTasks(domains);
      tasks.assignAll(result.tasks);
      failures
        ..clear()
        ..addAll(result.failures);
    } finally {
      isLoading.value = false;
    }
  }

  void selectFilter(TaskDomain? domain) => filter.value = domain;

  List<FieldTask> get visibleTasks {
    final selected = filter.value;
    return selected == null
        ? tasks
        : tasks.where((t) => t.domain == selected).toList();
  }

  /// No field module is active for this workspace.
  bool get hasNoDomains => domains.isEmpty;

  /// Every domain refused this account: it has field modules but no field
  /// role in any of them.
  bool get isAccessDenied =>
      domains.isNotEmpty &&
      failures.length == domains.length &&
      failures.values.every((e) => e.isForbidden);

  /// Every domain failed and at least one for a reason worth retrying.
  ApiException? get blockingError {
    if (domains.isEmpty || failures.length < domains.length || isAccessDenied) {
      return null;
    }
    return failures.values.firstWhere(
      (e) => !e.isForbidden,
      orElse: () => failures.values.first,
    );
  }

  /// Some domains answered, some could not be read for a reason other than
  /// "not your role" - shown as a notice above what did load.
  List<TaskDomain> get partiallyFailed => failures.entries
      .where((entry) => !entry.value.isForbidden)
      .map((entry) => entry.key)
      .toList();

  int get needsActionCount => tasks.where((t) => t.needsAction).length;
}
