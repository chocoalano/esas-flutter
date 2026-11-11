import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';

class InboxApiService {
  const InboxApiService(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> inbox() =>
      _client.getObject(ApiRoutes.tasksInbox);

  Future<Map<String, dynamic>> decide({
    required String taskId,
    required String decision,
    String? note,
  }) =>
      _client.postObject(
        '${ApiRoutes.tasksInbox}/$taskId/decision',
        {
          'decision': decision,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
}

