import 'package:get/get.dart';

import '../../data/models/field_task.dart';
import '../bindings/tasks_bindings.dart';
import '../views/my_tasks_view.dart';
import '../views/task_detail_view.dart';
import 'tasks_routes.dart';

class TasksPages {
  const TasksPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: TasksRoutes.myTasks,
      page: () => const MyTasksView(),
      binding: MyTasksBinding(),
    ),
    for (final domain in TaskDomain.values)
      GetPage(
        name: TasksRoutes.forDomain(domain),
        page: () => const MyTasksView(),
        binding: MyTasksBinding(initialDomain: domain),
      ),
    GetPage(
      name: TasksRoutes.detail,
      page: () => const TaskDetailView(),
      binding: TaskDetailBinding(),
    ),
  ];
}
