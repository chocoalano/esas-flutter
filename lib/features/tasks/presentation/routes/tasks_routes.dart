import '../../data/models/field_task.dart';

class TasksRoutes {
  const TasksRoutes._();

  /// Every field domain the workspace has.
  static const myTasks = '/tasks';

  /// The same list opened from a module tile, filtered to that domain.
  static String forDomain(TaskDomain domain) => '/tasks/${domain.name}';

  static const detail = '/tasks/detail';
}
