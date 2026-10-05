import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/env.dart';
import '../config/server_config.dart';
import '../tenancy/tenant_context.dart';
import 'api_error_mapper.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'upload.dart';

/// The one way this app talks to its backend.
///
/// Replaces `ApiProvider` and `ApiExternalProvider`, which between them owned
/// base URL, TLS policy, token reading, the auth decision, header sanitising,
/// the decoder, verb overrides, multipart upload, and four `external*` methods
/// that duplicated the other class and were called from nowhere (MED-02).
///
/// Registered **once**, in `InitialBinding`. The old provider was registered
/// four different ways — permanently in `main`, again in `SplashController`, and
/// lazily in three bindings — so twenty controllers called `Get.find` and none
/// of them could say which instance they got (HIGH-07).
///
/// The origin is resolved **per request**, not fixed when this object is built.
/// The address is a setting now, and in subdomain mode the workspace is part of
/// it, so a client constructed before somebody switched workspaces would
/// otherwise go on talking to the old tenant until the app restarted.
class ApiClient extends GetConnect {
  /// The unroutable origin relative paths are resolved against until a request
  /// is made.
  ///
  /// `.invalid` is reserved by RFC 2606 and can never resolve, so a request that
  /// somehow escaped the request modifier fails locally rather than reaching a
  /// stranger's server. Never a destination — see [onInit].
  static const String placeholderOrigin = 'https://unset.invalid';

  /// What `httpClient.baseUrl` is actually set to.
  ///
  /// **The API prefix is part of it, and that is load-bearing.** Every path in
  /// `ApiRoutes` is written relative to [Env.apiPrefix] and never repeats it, so
  /// the prefix can only enter a request from here: GetConnect resolves
  /// `/auth/login` against this base, and [rebase] then swaps the *origin* while
  /// keeping the path it produced.
  ///
  /// Dropping the prefix from this value therefore does not fail loudly. It
  /// sends every request to `<origin>/auth/login` instead of
  /// `<origin>/api/v1/auth/login`, and the server answers 404 "The route
  /// auth/login could not be found" — which reads as a backend problem and is
  /// not. That is exactly what happened when this was briefly a bare origin.
  static String get placeholderBaseUrl => '$placeholderOrigin${Env.apiPrefix}';

  /// How long a request that waits on face scoring is given.
  ///
  /// The budgets nest, innermost first, and this is the outermost. The backend
  /// waits on the face service for up to `FACE_API_CONNECT_TIMEOUT` (10 s) plus
  /// `FACE_API_TIMEOUT` (45 s) before it answers a submission — see
  /// `config/services.php` in `tenancy-app`, which states the 75 seconds the
  /// app is expected to allow. `esas_attendance` allows the same.
  ///
  /// This client used to give that request the 30 seconds everything else
  /// gets, which is the nesting backwards: the handset gave up first while the
  /// backend carried on and wrote the attendance. The person was clocked in,
  /// told the answer never arrived, and could not try again because their
  /// challenge was spent.
  static const Duration defaultScoringTimeout = Duration(seconds: 75);

  ApiClient({
    required ServerConfig serverConfig,
    required TenantContext tenantContext,
    required AuthInterceptor authInterceptor,
    Duration timeout = const Duration(seconds: 30),
    Duration scoringTimeout = defaultScoringTimeout,
    Future<void> Function()? onUnauthorized,
  }) : _serverConfig = serverConfig,
       _tenantContext = tenantContext,
       _auth = authInterceptor,
       _timeout = timeout,
       _scoringTimeout = scoringTimeout,
       _onUnauthorized = onUnauthorized;

  final ServerConfig _serverConfig;
  final TenantContext _tenantContext;
  final AuthInterceptor _auth;
  final Duration _timeout;
  final Duration _scoringTimeout;

  /// The transport for a request that waits on face scoring: the same origin
  /// resolution and the same headers, with [_scoringTimeout] as its deadline.
  ///
  /// A second transport rather than a second value on the first. GetConnect
  /// keeps one `timeout` per client and reads it again after the connection has
  /// opened, so raising it around one call would raise it for whatever else was
  /// in flight — and let that other request put it back in the middle of the
  /// upload this exists for.
  ///
  /// Built on first use: most sessions never clock by face.
  GetHttpClient? _scoringClient;

  /// Called once when an **authenticated** request is refused with 401.
  ///
  /// The one place a dead session is noticed. Before this, three controllers
  /// each mapped 401 to their own Indonesian sentence and **none of them ended
  /// the session** — so an employee whose token expired mid-session saw "Akses
  /// ditolak. Silakan login ulang." on every screen while remaining stuck in an
  /// authenticated shell that no longer worked (MED-07).
  ///
  /// Deliberately **401 only**. A 403 means this account may not do this
  /// particular thing; signing somebody out for it would eject a user who is
  /// perfectly well authenticated (R-07).
  ///
  /// Deliberately **authenticated requests only**. A 401 from `login` means the
  /// credentials were wrong, not that a session died.
  final Future<void> Function()? _onUnauthorized;

  @override
  void onInit() {
    // A placeholder base, and never the address a request is actually sent to.
    // GetConnect needs *some* base to resolve a relative path against, the real
    // origin is not known until the request is made, and the modifier below
    // swaps it in. Not left empty, because an unresolvable relative path throws
    // before any modifier can run.
    //
    // It carries the API prefix. The modifier replaces the ORIGIN and keeps the
    // path, so `/api/v1` reaches the server from here or from nowhere — see
    // [placeholderBaseUrl].
    _configure(httpClient, _timeout);
  }

  @override
  void dispose() {
    _scoringClient?.close();
    _scoringClient = null;
    super.dispose();
  }

  /// Point a transport at the placeholder base and resolve the real origin per
  /// request. One method for both transports, so the one that carries a face
  /// capture cannot come to disagree with the other about where the server is.
  GetHttpClient _configure(GetHttpClient client, Duration timeout) {
    client.baseUrl = placeholderBaseUrl;
    client.timeout = timeout;

    client.addRequestModifier<Object?>((request) {
      final origin = _serverConfig.originFor(_tenantContext.tenant);

      if (origin == null) {
        return request;
      }

      return request.copyWith(url: rebase(request.url, origin));
    });

    return client;
  }

  GetHttpClient get _scoring => _scoringClient ??= _configure(
    GetHttpClient(
      userAgent: userAgent,
      sendUserAgent: sendUserAgent,
      followRedirects: followRedirects,
      maxRedirects: maxRedirects,
      maxAuthRetries: maxAuthRetries,
      allowAutoSignedCert: allowAutoSignedCert,
      trustedCertificates: trustedCertificates,
      withCredentials: withCredentials,
      findProxy: findProxy,
    ),
    _scoringTimeout,
  );

  /// Move [url] onto [origin], keeping the path and query it already carries.
  ///
  /// Built up from the origin rather than by replacing fields on [url], because
  /// `Uri.replace` cannot *remove* a port: asking it for port 0 writes a literal
  /// `:0` into the address, so a placeholder's `:9443` would follow the request
  /// onto a server answering on 443.
  @visibleForTesting
  static Uri rebase(Uri url, String origin) {
    return Uri.parse(
      origin,
    ).replace(path: url.path, query: url.hasQuery ? url.query : null);
  }

  // ── Verbs ────────────────────────────────────────────────────────────────
  //
  // Named for what they return, because the backend answers some endpoints with
  // an object and some with a bare array, and a caller that guesses wrong gets a
  // cast error inside `fromJson` where the field name is already lost (MED-04).

  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      () => get(
        path,
        query: _stringifyQuery(query),
        headers: _auth.headersFor(authenticated: authenticated, extra: headers),
      ),
    );

    return _guardSession(authenticated, () => _asObject(response));
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      () => get(
        path,
        query: _stringifyQuery(query),
        headers: _auth.headersFor(authenticated: authenticated, extra: headers),
      ),
    );

    return _guardSession(authenticated, () => _asList(response));
  }

  Future<Map<String, dynamic>> postObject(
    String path,
    Object? body, {
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      () => post(
        path,
        body,
        query: _stringifyQuery(query),
        headers: _auth.headersFor(authenticated: authenticated, extra: headers),
      ),
    );

    return _guardSession(authenticated, () => _asObject(response));
  }

  Future<Map<String, dynamic>> putObject(
    String path,
    Object? body, {
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      () => put(
        path,
        body,
        headers: _auth.headersFor(authenticated: authenticated, extra: headers),
      ),
    );

    return _guardSession(authenticated, () => _asObject(response));
  }

  Future<Map<String, dynamic>> patchObject(
    String path,
    Object? body, {
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      () => patch(
        path,
        body,
        headers: _auth.headersFor(authenticated: authenticated, extra: headers),
      ),
    );

    return _guardSession(authenticated, () => _asObject(response));
  }

  /// One multipart field, as text a server will actually accept.
  ///
  /// Multipart has no types: every field crosses as a string, and the encoding
  /// chosen here is the contract. Two rules, and the second one cost a whole
  /// feature.
  ///
  /// **Null and blank are dropped** rather than sent as the string `"null"`,
  /// which is what a naive `toString()` over a field map produces and what the
  /// permit form used to send.
  ///
  /// **A `bool` is `'1'` or `'0'`, never `"true"` or `"false"`.** Laravel's
  /// `boolean` rule accepts exactly `[true, false, 0, 1, '0', '1']` and compares
  /// with a STRICT `in_array`, so the string `"false"` is not a false — it is a
  /// validation failure. Face attendance sends `is_mocked: false` on every
  /// submission, so every face clock was refused with a 422 that carried no
  /// `code`; the screen classified that by status alone and told the employee
  /// "Absensi belum dapat diproses". The QR paths were unaffected because they
  /// post JSON, where a bool stays a bool — which is exactly why this was
  /// invisible until somebody used the face method.
  static String? encodeFormField(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is bool) {
      return value ? '1' : '0';
    }

    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  /// Post a multipart form.
  ///
  /// Fields are encoded by [encodeFormField]; read it before adding a field of
  /// a type that is not a string or a number.
  ///
  /// [awaitsScoring] is for the one form whose answer waits on the face
  /// service, and gives it the scoring deadline ([defaultScoringTimeout])
  /// instead of the one everything else is held to. Not a general "this might be slow" switch: a
  /// longer wait is only right where the backend is known to be waiting too.
  Future<Map<String, dynamic>> postForm(
    String path,
    Map<String, dynamic> fields, {
    Map<String, Upload> files = const {},
    bool authenticated = true,
    Map<String, String>? headers,
    bool awaitsScoring = false,
  }) async {
    final form = FormData({});

    fields.forEach((key, value) {
      final text = encodeFormField(value);

      if (text != null) {
        form.fields.add(MapEntry(key, text));
      }
    });

    files.forEach((key, upload) {
      // `upload.payload` is a `File` or the bytes a pathless picker returned;
      // `MultipartFile` reads both.
      form.files.add(
        MapEntry(key, MultipartFile(upload.payload, filename: upload.filename)),
      );
    });

    final requestHeaders = _auth.headersFor(
      authenticated: authenticated,
      extra: headers,
    );

    final response = await _send(
      () => awaitsScoring
          ? _scoring.post<dynamic>(path, body: form, headers: requestHeaders)
          : post(path, form, headers: requestHeaders),
    );

    return _guardSession(authenticated, () => _asObject(response));
  }

  // ── Plumbing ─────────────────────────────────────────────────────────────

  /// Unwrap a response, and notify once if an authenticated call was refused
  /// with 401.
  ///
  /// The exception is rethrown either way: ending the session is a side effect,
  /// not a substitute for telling the caller its request failed.
  Future<T> _guardSession<T>(bool authenticated, T Function() unwrap) async {
    try {
      return unwrap();
    } on ApiException catch (error) {
      if (authenticated && error.isUnauthenticated) {
        await _onUnauthorized?.call();
      }

      rethrow;
    }
  }

  /// Run a request, turning any transport failure into an [ApiException] so a
  /// caller has exactly one thing to catch.
  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() send,
  ) async {
    return guardFailure(send);
  }

  /// The failure translation on its own, so it can be exercised without a
  /// socket. Every path out of it either returns or throws [ApiException].
  @visibleForTesting
  static Future<T> guardFailure<T>(Future<T> Function() send) async {
    try {
      return await send();
    } catch (error) {
      throw ApiErrorMapper.fromTransportError(error);
    }
  }

  /// Decode a successful response, or throw what the server refused with.
  @visibleForTesting
  static Map<String, dynamic> unwrapObject(Response<dynamic> response) {
    _throwIfRefused(response);

    final body = response.body;

    if (body is Map) {
      return Map<String, dynamic>.from(body);
    }

    // An empty 200 — a logout, an acknowledgement — is a success with nothing
    // in it, not a malformed response.
    if (body == null || (body is String && body.trim().isEmpty)) {
      return const {};
    }

    throw const ApiException(
      'Kesalahan format data dari server.',
      code: 'malformed_response',
    );
  }

  @visibleForTesting
  static List<dynamic> unwrapList(Response<dynamic> response) {
    _throwIfRefused(response);

    final body = response.body;

    if (body is List) {
      return body;
    }

    // Some endpoints wrap their array in `{"data": [...]}` and some do not.
    if (body is Map && body['data'] is List) {
      return body['data'] as List;
    }

    if (body == null || (body is String && body.trim().isEmpty)) {
      return const [];
    }

    throw const ApiException(
      'Kesalahan format data dari server.',
      code: 'malformed_response',
    );
  }

  static void _throwIfRefused(Response<dynamic> response) {
    if (response.isOk) {
      return;
    }

    // A null status means the request never reached a server. Kept distinct
    // from a refusal because the two deserve opposite responses: a refusal is
    // the server's verdict, a transport failure is a reason to keep the session
    // and retry rather than sign the user out (HIGH-02).
    if (response.statusCode == null || response.status.connectionError) {
      // A deadline that passed is not a network that is down, and GetConnect
      // reports the two identically: it catches its own `TimeoutException` and
      // hands back a response with no status, keeping only the exception's text
      // in `statusText`. Read back out of it here, because the difference
      // decides what an employee is told after a clock — "nothing was sent,
      // try again" for a dead socket, "it may have been recorded, check first"
      // for an answer that never came. Without this every timeout was the
      // former.
      if ((response.statusText ?? '').startsWith('TimeoutException')) {
        throw ApiErrorMapper.fromTransportError(
          TimeoutException(response.statusText),
        );
      }

      throw const ApiException(
        'Tidak ada koneksi internet. Periksa jaringan Anda.',
        code: 'network_unreachable',
      );
    }

    throw ApiErrorMapper.fromResponse(
      status: response.statusCode,
      body: response.body,
    );
  }

  Map<String, dynamic> _asObject(Response<dynamic> r) => unwrapObject(r);

  List<dynamic> _asList(Response<dynamic> r) => unwrapList(r);

  /// GetConnect encodes query values as-is. Stringifying here keeps an `int`
  /// page number from arriving as something the server reads differently, and
  /// drops nulls rather than sending `key=null`.
  ///
  /// Callers pass a map instead of hand-building `?page=1&limit=10`, which is
  /// what the notification and permit controllers did — string concatenation
  /// that corrupts the request the moment a value contains `&` (MED-01).
  @visibleForTesting
  static Map<String, dynamic>? stringifyQuery(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) {
      return null;
    }

    final result = <String, dynamic>{};

    query.forEach((key, value) {
      if (value != null) {
        result[key] = value.toString();
      }
    });

    return result.isEmpty ? null : result;
  }

  Map<String, dynamic>? _stringifyQuery(Map<String, dynamic>? q) =>
      stringifyQuery(q);
}
