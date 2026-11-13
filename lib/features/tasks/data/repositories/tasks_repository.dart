import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/json_parsers.dart';
import '../models/field_task.dart';
import '../services/tasks_api_service.dart';

/// What one load of "Tugas Saya" found: the tasks, and the domains that could
/// not be read (and why), so one failing module does not hide the others.
class TaskListResult {
  const TaskListResult({required this.tasks, this.failures = const {}});

  final List<FieldTask> tasks;
  final Map<TaskDomain, ApiException> failures;

  bool get isEmpty => tasks.isEmpty;
}

class TasksRepository {
  const TasksRepository(this._api);

  final TasksApiService _api;

  /// The caller's tasks across [domains], asked of each domain's own API in
  /// parallel. Tasks that need the worker's action come first.
  Future<TaskListResult> myTasks(List<TaskDomain> domains) async {
    final failures = <TaskDomain, ApiException>{};
    final batches = await Future.wait(
      domains.map((domain) async {
        try {
          final body = await _api.list(domain);
          return asList(body['data'])
              .whereType<Map>()
              .map(
                (json) =>
                    FieldTask.fromJson(domain, Map<String, dynamic>.from(json)),
              )
              .toList();
        } on ApiException catch (e) {
          failures[domain] = e;
          return const <FieldTask>[];
        }
      }),
    );

    final tasks = batches.expand((batch) => batch).toList()
      ..sort((a, b) {
        if (a.needsAction != b.needsAction) return a.needsAction ? -1 : 1;
        return (b.scheduledAt ?? DateTime(0)).compareTo(
          a.scheduledAt ?? DateTime(0),
        );
      });

    return TaskListResult(tasks: tasks, failures: failures);
  }

  Future<FieldTaskDetail> detail(TaskDomain domain, int id) async {
    final body = await _api.detail(domain, id);
    return FieldTaskDetail.fromJson(domain, asObject(body['data']));
  }

  /// Run one action and return the task as the server now has it.
  Future<FieldTaskDetail> act(
    TaskDomain domain,
    int id,
    String path,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) async {
    final response = await _api.act(
      domain,
      id,
      path,
      body,
      idempotencyKey: idempotencyKey,
    );
    return FieldTaskDetail.fromJson(domain, asObject(response['data']));
  }
}
