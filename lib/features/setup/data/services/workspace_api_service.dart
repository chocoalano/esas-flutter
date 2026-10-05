import 'dart:convert';
import 'dart:io';

import '../../../../core/config/api_routes.dart';
import '../../../../core/config/env.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/utils/json_parsers.dart';
import '../../../../core/tenancy/workspace_clock.dart';
import '../models/workspace.dart';

/// One request, sent for one purpose: does this address, with this workspace on
/// it, reach a workspace at all.
typedef WorkspaceProbe =
    Future<({int? status, Object? body})> Function(
      Uri url,
      Map<String, String> headers,
    );

/// Asks the server to name the workspace a handset is being pointed at.
///
/// ## Why this does not go through `ApiClient`
///
/// ADR-0004 says one client, and this is not a second one — it is the one call
/// that cannot use it, for two reasons that both come down to the same thing:
/// at the moment it is made, none of what `ApiClient` resolves a request from
/// has been decided yet.
///
/// * **The address is a candidate.** `ApiClient` rebases every request onto
///   `ServerConfig.originFor(tenant)` — the *stored* address. The probe's whole
///   job is to test one nobody has agreed to store.
/// * **The prefix is the platform's, not this client's.** `ApiClient` carries
///   `Env.apiPrefix` in its base URL; the probe is answered at
///   `Env.platformApiPrefix` (see ADR-0007, still open). GetConnect composes a
///   URL by concatenating its base with the path, so there is no honest way to
///   ask for a different prefix through it.
///
/// The sibling app `esas_attendance` reaches the same conclusion and gives the
/// probe its own provider. What is *not* duplicated is policy: the header
/// decision is `AuthInterceptor.buildHeaders`, the status mapping is
/// `ApiErrorMapper`, and the failure type is the same `ApiException` every other
/// call in this app throws.
class WorkspaceApiService {
  WorkspaceApiService({
    WorkspaceProbe? probe,
    Duration timeout = const Duration(seconds: 15),
  }) : _probe = probe ?? _sendOverHttp,
       _timeout = timeout;

  final WorkspaceProbe _probe;
  final Duration _timeout;

  /// Ask [origin] whether it hosts [workspace], and what it is called.
  ///
  /// Unauthenticated, because setup happens before there is an account to ask
  /// as: a token is what signing in produces, not what checking an address
  /// requires.
  Future<Workspace> check({
    required String origin,
    required String workspace,
  }) async {
    final url = Uri.parse(
      '$origin${Env.platformApiPrefix}${ApiRoutes.workspace}',
    );
    final headers = AuthInterceptor.buildHeaders(
      authenticated: false,
      tenant: workspace,
    );

    final ({int? status, Object? body}) answer;

    try {
      answer = await _probe(url, headers).timeout(_timeout);
    } catch (error) {
      // A dead socket, a name that resolves to nothing, a stalled connection —
      // all of it arrives as the same type as a refusal, so the caller has one
      // thing to catch and one thing to explain.
      throw ApiErrorMapper.fromTransportError(error);
    }

    final status = answer.status;

    if (status == null || status < 200 || status >= 300) {
      throw ApiErrorMapper.fromResponse(status: status, body: answer.body);
    }

    final confirmed = Workspace.fromJson(
      asObject(answer.body),
      fallback: workspace,
    );

    // Publish the clock as soon as it is known. The login screen draws times
    // too, and a handset that has never signed in has no session to read one
    // from — so without this the very first screen renders in the fallback zone.
    WorkspaceClock.current = confirmed.clock;

    return confirmed;
  }

  /// The default transport.
  ///
  /// A bare `HttpClient` rather than a package, because this is one GET with no
  /// body, no auth and no session semantics. It picks up `HttpOverrides.global`
  /// like everything else in the app, so the TLS policy here is the app's TLS
  /// policy and not a second one (CRIT-02 is closed in one place, not two).
  static Future<({int? status, Object? body})> _sendOverHttp(
    Uri url,
    Map<String, String> headers,
  ) async {
    final client = HttpClient();

    try {
      final request = await client.getUrl(url);

      headers.forEach((name, value) => request.headers.set(name, value));

      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();

      return (status: response.statusCode, body: _decode(text));
    } finally {
      client.close(force: true);
    }
  }

  /// Decode a body, or give up on it quietly.
  ///
  /// A wrong address often answers with somebody else's HTML. Letting that throw
  /// would report "format tidak sesuai" for what is really a 404, and the status
  /// is the more useful half of the answer — so a body that will not parse is
  /// dropped and the status is left to speak.
  static Object? _decode(String text) {
    if (text.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
