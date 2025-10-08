import 'package:get/get.dart';
import 'package:flutter/foundation.dart'; // kDebugMode

/// Provider khusus API eksternal:
/// - Tidak memakai baseUrl (WAJIB URL absolut).
/// - Mendukung default headers (global) + custom headers per request (dinamis).
/// - Opsi withAuth untuk menyuntik Authorization dari token yang diset via setAuthToken().
class ApiExternalProvider extends GetConnect {
  // optional kalau nanti butuh
  final Map<String, String> _defaultHeaders = {}; // header global
  String? _authToken; // token untuk Authorization
  String _authScheme = 'Bearer'; // skema Authorization (default Bearer)

  // ====== Public API untuk header dinamis/global ======

  /// Set/overwrite satu default header global.
  void setDefaultHeader(String key, String value) {
    _defaultHeaders[key] = value;
  }

  /// Set beberapa default header sekaligus (merge).
  void setDefaultHeaders(Map<String, String> headers) {
    _defaultHeaders.addAll(headers);
  }

  /// Hapus satu default header global.
  void removeDefaultHeader(String key) {
    _defaultHeaders.remove(key);
  }

  /// Hapus semua default header (reset).
  void clearDefaultHeaders() {
    _defaultHeaders.clear();
  }

  /// Set token Authorization global (opsional).
  /// Gunakan [scheme] untuk ganti "Bearer" (mis. "ApiKey", "Basic", dll.)
  void setAuthToken(String token, {String scheme = 'Bearer'}) {
    _authToken = token;
    _authScheme = scheme;
  }

  /// Hapus token Authorization global.
  void clearAuthToken() {
    _authToken = null;
  }

  // ====== Util ======

  bool _isAbsoluteUrl(String? url) {
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  Map<String, String> _mergeHeaders({
    Map<String, String>? headers,
    bool withAuth = false,
    bool? bypassAuth, // null => auto true
  }) {
    final merged = <String, String>{
      ..._defaultHeaders, // default/global
      ...?headers, // per-request (override default)
    };

    // Ensure Accept default
    merged.putIfAbsent('Accept', () => 'application/json');

    // Inject Authorization kalau diminta & ada token
    if (withAuth && _authToken != null && _authToken!.isNotEmpty) {
      merged['Authorization'] = '$_authScheme $_authToken';
    }

    // Pasang X-Bypass-Auth (default true untuk eksternal),
    // tapi hormati explicit value dari caller.
    final shouldBypass = bypassAuth ?? true;
    merged.putIfAbsent('X-Bypass-Auth', () => shouldBypass ? 'true' : 'false');

    return merged;
  }

  @override
  void onInit() {
    // Mode eksternal murni
    httpClient.baseUrl = null;
    allowAutoSignedCert = true;

    httpClient.addRequestModifier<dynamic>((request) async {
      final url = request.url.toString();
      if (!_isAbsoluteUrl(url)) {
        if (kDebugMode) {
          debugPrint('[ApiExternalProvider] URL harus absolut -> $url');
        }
        throw ArgumentError(
          'ApiExternalProvider hanya menerima URL absolut: $url',
        );
      }
      // Jangan sentuh header di sini; semuanya diatur di pemanggilan (mergeHeaders).
      return request;
    });

    httpClient.addResponseModifier((request, response) {
      return response;
    });

    httpClient.defaultDecoder = (dynamic data) {
      if (data is String && data.isEmpty) return {};
      return data;
    };
  }

  // ====== Override Get/Post standar (boleh dipakai langsung) ======
  // Tetap izinkan custom header dinamis di parameter.

  @override
  Future<Response<T>> get<T>(
    String? url, {
    Map<String, String>? params,
    Map<String, String>? headers,
    String? contentType,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
  }) {
    assert(url != null && url.isNotEmpty, 'URL tidak boleh null/kosong');
    assert(
      _isAbsoluteUrl(url),
      'ApiExternalProvider hanya menerima URL absolut',
    );

    final finalQuery = <String, dynamic>{...?query, ...?params};
    final mergedHeaders = _mergeHeaders(
      headers: headers,
      // default: bypassAuth true; withAuth false (tidak injeksi token kecuali diminta)
    );

    return super.get(
      url!,
      headers: mergedHeaders,
      contentType: contentType,
      query: finalQuery.isEmpty ? null : finalQuery,
      decoder: decoder,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String? url,
    dynamic body, {
    Map<String, String>? headers,
    String? contentType,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
    Progress? uploadProgress,
  }) {
    assert(url != null && url.isNotEmpty, 'URL tidak boleh null/kosong');
    assert(
      _isAbsoluteUrl(url),
      'ApiExternalProvider hanya menerima URL absolut',
    );

    final mergedHeaders = _mergeHeaders(headers: headers);

    return super.post(
      url!,
      body,
      headers: mergedHeaders,
      contentType: contentType,
      query: (query == null || query.isEmpty) ? null : query,
      decoder: decoder,
      uploadProgress: uploadProgress,
    );
  }

  // ====== Helper khusus eksternal (lebih ergonomis) ======
  // Ada opsi withAuth & bypassAuth per-request + custom headers dinamis.

  Future<Response<T>> getExternal<T>(
    String absoluteUrl, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? contentType,
    Decoder<T>? decoder,
    bool withAuth = false,
    bool? bypassAuth,
  }) {
    assert(_isAbsoluteUrl(absoluteUrl), 'URL harus absolut');
    final mergedHeaders = _mergeHeaders(
      headers: headers,
      withAuth: withAuth,
      bypassAuth: bypassAuth,
    );

    return super.get(
      absoluteUrl,
      headers: mergedHeaders,
      contentType: contentType,
      query: (query == null || query.isEmpty) ? null : query,
      decoder: decoder,
    );
  }

  Future<Response<T>> postExternal<T>(
    String absoluteUrl,
    dynamic body, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? contentType,
    Decoder<T>? decoder,
    Progress? uploadProgress,
    bool withAuth = false,
    bool? bypassAuth,
  }) {
    assert(_isAbsoluteUrl(absoluteUrl), 'URL harus absolut');
    final mergedHeaders = _mergeHeaders(
      headers: headers,
      withAuth: withAuth,
      bypassAuth: bypassAuth,
    );

    return super.post(
      absoluteUrl,
      body,
      headers: mergedHeaders,
      contentType: contentType,
      query: (query == null || query.isEmpty) ? null : query,
      decoder: decoder,
      uploadProgress: uploadProgress,
    );
  }

  Future<Response<T>> uploadExternal<T>(
    String absoluteUrl,
    FormData formData, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Decoder<T>? decoder,
    Progress? uploadProgress,
    bool withAuth = false,
    bool? bypassAuth,
  }) {
    assert(_isAbsoluteUrl(absoluteUrl), 'URL harus absolut');
    final mergedHeaders = _mergeHeaders(
      headers: headers,
      withAuth: withAuth,
      bypassAuth: bypassAuth,
    );

    return super.post(
      absoluteUrl,
      formData,
      headers: mergedHeaders,
      query: (query == null || query.isEmpty) ? null : query,
      decoder: decoder,
      uploadProgress: uploadProgress,
    );
  }
}
