import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/idempotency_key.dart';
import '../models/field_task.dart';

/// The worker-task endpoints of each domain. Every list and detail is already
/// scoped by the server to what is assigned to the caller; nothing here
/// filters someone else's work out on the handset.
class TasksApiService {
  const TasksApiService(this._client);

  final ApiClient _client;

  static String base(TaskDomain domain) => switch (domain) {
    TaskDomain.gams => ApiRoutes.gamsMyWorkOrders,
    TaskDomain.itms => ApiRoutes.itmsAssignedTickets,
    TaskDomain.mtms => ApiRoutes.mtmsMyWorkOrders,
  };

  Future<Map<String, dynamic>> list(TaskDomain domain, {int page = 1}) =>
      _client.getObject(
        base(domain),
        // Open work only: finished tasks never crowd open ones off the page.
        query: {'page': page, 'per_page': 50, 'state': 'open'},
      );

  Future<Map<String, dynamic>> detail(TaskDomain domain, int id) =>
      _client.getObject('${base(domain)}/$id');

  /// One action. [idempotencyKey] names the attempt: the same value on a
  /// retry makes the server replay its first answer instead of acting twice.
  Future<Map<String, dynamic>> act(
    TaskDomain domain,
    int id,
    String path,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) => _client.postObject(
    '${base(domain)}/$id/$path',
    body,
    headers: IdempotencyKey.headerFor(idempotencyKey),
  );
}
