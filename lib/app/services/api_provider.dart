import 'package:esas/utils/api_constants.dart'; // Ensure this path is correct
import 'package:esas/app/widgets/controllers/storage_keys.dart'; // Ensure this path is correct
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class ApiProvider extends GetConnect {
  final GetStorage _storage = GetStorage();

  // === Utility ===
  bool _isAbsoluteUrl(String? url) {
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  bool _isInternalUri(Uri uri) {
    if ((httpClient.baseUrl ?? '').isEmpty) return false;
    final base = Uri.tryParse(httpClient.baseUrl!);
    if (base == null || base.host.isEmpty) return false;
    return uri.host == base.host;
  }

  @override
  void onInit() {
    // OPTIONAL: aktifkan baseUrl hanya kalau kamu memang ingin pakai untuk internal.
    // Jika ingin benar-benar tanpa baseUrl global, cukup komentari baris di bawah.
    httpClient.baseUrl = (baseApiUrl); // atau komentari jika mau kosong total

    allowAutoSignedCert = true;

    httpClient.addRequestModifier<dynamic>((request) async {
      // Jika ada header pengaman untuk bypass, jangan suntik header apapun.
      final bypassAuth = request.headers['X-Bypass-Auth'] == 'true';

      // Selalu bisa set Accept default jika tidak di-set caller
      request.headers.putIfAbsent('Accept', () => 'application/json');

      // Tambah Authorization HANYA jika:
      // - tidak bypass, DAN
      // - URL internal (host sama dengan baseUrl) ATAU URL bukan absolute (akan digabung baseUrl)
      try {
        final uri = Uri.parse(request.url.toString());
        final shouldAuth =
            !bypassAuth &&
            ((httpClient.baseUrl ?? '').isNotEmpty
                ? (!_isAbsoluteUrl(request.url.toString()) ||
                      _isInternalUri(uri))
                : false);

        if (shouldAuth) {
          final token = _storage.read(StorageKeys.token);
          if (token != null && token is String && token.isNotEmpty) {
            request.headers['Authorization'] = 'Bearer $token';
          }
        }
      } catch (_) {
        // Abaikan parsing error; jangan suntik auth
      }

      // Bersihkan header bypass agar tidak terkirim ke server
      request.headers.remove('X-Bypass-Auth');
      return request;
    });

    httpClient.addResponseModifier((request, response) {
      return response;
    });

    httpClient.defaultDecoder = (dynamic data) {
      if (data is String && data.isEmpty) {
        return {};
      }
      try {
        return data;
      } catch (e) {
        debugPrint('Error decoding response: $e Response data: $data');
        return data;
      }
    };
  }

  // --- GET override: mendukung params/query & bisa bypass auth via header ---
  @override
  Future<Response<T>> get<T>(
    String? url, {
    Map<String, String>? params, // akan digabung ke query
    Map<String, String>? headers,
    String? contentType,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
  }) {
    assert(url != null && url.isNotEmpty, 'URL tidak boleh null/kosong');

    // Gabungkan params (String,String) ke query (String,dynamic)
    final Map<String, dynamic> finalQuery = {...?query, ...?params};

    // Headers final (boleh kosong)
    final Map<String, String> finalHeaders = {...?headers};

    // Jika URL absolute (eksternal), otomatis bypass auth & baseUrl
    if (_isAbsoluteUrl(url)) {
      finalHeaders['X-Bypass-Auth'] = finalHeaders['X-Bypass-Auth'] ?? 'true';
    }

    // Jika ada params di URL, pastikan tidak dobel: lib GetConnect akan handle merge query
    return super.get(
      url!,
      headers: finalHeaders,
      contentType: contentType,
      query: finalQuery.isEmpty ? null : finalQuery,
      decoder: decoder,
    );
  }

  // --- POST override: bisa bypass via header X-Bypass-Auth ---
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

    final Map<String, String> finalHeaders = {...?headers};

    if (_isAbsoluteUrl(url)) {
      finalHeaders['X-Bypass-Auth'] = finalHeaders['X-Bypass-Auth'] ?? 'true';
    }

    return super.post(
      url!,
      body,
      headers: finalHeaders,
      contentType: contentType,
      query: (query == null || query.isEmpty) ? null : query,
      decoder: decoder,
      uploadProgress: uploadProgress,
    );
  }

  // --- POST Multipart/FormData (file upload) ---
  Future<Response<T>> postFormData<T>(
    String url,
    FormData formData, {
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
    Progress? uploadProgress,
  }) {
    final Map<String, String> finalHeaders = {...?headers};

    // Bypass auth otomatis jika absolute URL
    if (_isAbsoluteUrl(url)) {
      finalHeaders['X-Bypass-Auth'] = finalHeaders['X-Bypass-Auth'] ?? 'true';
    }

    return super.post(
      url,
      formData,
      headers: finalHeaders,
      query: (query == null || query.isEmpty) ? null : query,
      decoder: decoder,
      uploadProgress: uploadProgress,
    );
  }

  // === Convenience methods khusus eksternal (tanpa sentuh override) ===
  Future<Response<T>> externalGet<T>(
    String absoluteUrl, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Decoder<T>? decoder,
  }) {
    final merged = {...?headers, 'X-Bypass-Auth': 'true'};
    return super.get(
      absoluteUrl,
      headers: merged,
      query: (query == null || query.isEmpty) ? null : query,
      decoder: decoder,
    );
  }

  Future<Response<T>> externalPost<T>(
    String absoluteUrl,
    dynamic body, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? contentType,
    Decoder<T>? decoder,
    Progress? uploadProgress,
  }) {
    final merged = {...?headers, 'X-Bypass-Auth': 'true'};
    return super.post(
      absoluteUrl,
      body,
      headers: merged,
      contentType: contentType,
      query: (query == null || query.isEmpty) ? null : query,
      decoder: decoder,
      uploadProgress: uploadProgress,
    );
  }

  Future<Response<T>> externalPostFormData<T>(
    String absoluteUrl,
    FormData formData, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Decoder<T>? decoder,
    Progress? uploadProgress,
  }) {
    final merged = {...?headers, 'X-Bypass-Auth': 'true'};
    return super.post(
      absoluteUrl,
      formData,
      headers: merged,
      query: (query == null || query.isEmpty) ? null : query,
      decoder: decoder,
      uploadProgress: uploadProgress,
    );
  }
}
