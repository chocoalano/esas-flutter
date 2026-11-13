import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/repositories/session_repository.dart';
import '../../data/models/field_task.dart';
import '../../data/repositories/tasks_repository.dart';
import '../../data/services/tasks_api_service.dart';
import '../controllers/my_tasks_controller.dart';
import '../controllers/task_detail_controller.dart';

TasksRepository _repository() =>
    TasksRepository(TasksApiService(Get.find<ApiClient>()));

/// The field domains this workspace has active, read from the session: a
/// domain the tenant does not have is never asked.
List<TaskDomain> activeTaskDomains() {
  final user = Get.isRegistered<SessionRepository>()
      ? Get.find<SessionRepository>().user
      : null;
  final active = (user?.activeModules ?? const <String>[])
      .map((m) => m.trim().toLowerCase())
      .toSet();

  return TaskDomain.values.where((d) => active.contains(d.module)).toList();
}

class MyTasksBinding extends Bindings {
  MyTasksBinding({this.initialDomain});

  final TaskDomain? initialDomain;

  @override
  void dependencies() {
    Get.lazyPut<MyTasksController>(
      () => MyTasksController(
        repository: _repository(),
        domains: activeTaskDomains(),
        initialDomain: initialDomain,
      ),
    );
  }
}

class TaskDetailBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments is Map ? Get.arguments as Map : const {};

    Get.lazyPut<TaskDetailController>(
      () => TaskDetailController(
        repository: _repository(),
        domain: TaskDomain.of('${args['domain']}') ?? TaskDomain.gams,
        id: args['id'] is int
            ? args['id'] as int
            : int.tryParse('${args['id']}') ?? 0,
      ),
    );
  }
}
