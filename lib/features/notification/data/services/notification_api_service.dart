import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';

class NotificationApiService {
  const NotificationApiService(this._client);

  final ApiClient _client;

  /// A page of notifications, plus `unread_count`.
  ///
  /// The count comes with the page rather than needing its own request: the
  /// badge is drawn from it, and a badge that needs a second round trip is
  /// wrong for a second every time the screen opens.
  ///
  /// The controller used to build `'?page=$p&limit=$n'` by hand (MED-01).
  Future<Map<String, dynamic>> page({
    required int page,
    required int perPage,
    bool unreadOnly = false,
  }) {
    return _client.getObject(
      ApiRoutes.notifications,
      query: {'page': page, 'per_page': perPage, if (unreadOnly) 'unread': 1},
    );
  }

  /// **PATCH**, not GET. Marking one read is a change to it, and the retired
  /// backend answering that on a GET meant any crawler or prefetch could clear
  /// somebody's notifications for them.
  ///
  /// A second call is success rather than a conflict — the client is allowed to
  /// be sure.
  Future<Map<String, dynamic>> markAsRead(String id) =>
      _client.patchObject(ApiRoutes.readNotification(id), const {});
}
