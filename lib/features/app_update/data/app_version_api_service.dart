import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'app_version_info.dart';

/// Reads the active version from the public, tenant-agnostic version endpoint.
class AppVersionApiService {
  AppVersionApiService(this._client);

  final ApiClient _client;

  /// Relative to the API prefix, like every path in ApiRoutes. Kept here
  /// rather than in ApiRoutes because that file is being changed elsewhere;
  /// move it there when that work lands.
  static const String path = '/app/version';

  /// The active version, or null when none is published for this app and
  /// platform (404). Any other failure is thrown, so the caller can tell
  /// "nothing to update to" apart from "could not ask".
  Future<AppVersionInfo?> fetch({
    required String application,
    required String platform,
  }) async {
    try {
      final body = await _client.getObject(
        path,
        query: {'app': application, 'platform': platform},
        authenticated: false,
      );

      return AppVersionInfo.fromJson(body);
    } on ApiException catch (error) {
      if (error.status == 404) {
        return null;
      }

      rethrow;
    }
  }
}
