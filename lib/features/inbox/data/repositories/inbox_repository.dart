import '../../../../core/utils/json_parsers.dart';
import '../models/approval_task.dart';
import '../services/inbox_api_service.dart';

class InboxRepository {
  const InboxRepository(this._api);

  final InboxApiService _api;

  Future<List<ApprovalTask>> tasks() async {
    final response = await _api.inbox();
    final data = asList(response['data']);
    return data.map((item) => ApprovalTask.fromJson(asObject(item))).toList();
  }

  Future<Map<String, dynamic>> decideTask({
    required String taskId,
    required String decision,
    String? note,
  }) => _api.decide(taskId: taskId, decision: decision, note: note);
}
