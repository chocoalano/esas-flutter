import 'package:esas/utils/api_constants.dart'; // Ensure this path is correct
import 'package:esas/app/widgets/controllers/storage_keys.dart'; // Ensure this path is correct
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class ApiProvider extends GetConnect {
  final GetStorage _storage = GetStorage();

  @override
  void onInit() {
    httpClient.baseUrl = baseApiUrl;
    allowAutoSignedCert = true;

    httpClient.addRequestModifier<dynamic>((request) async {
      final token = _storage.read(StorageKeys.token);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';
      return request;
    });

    httpClient.addResponseModifier((request, response) {
      // if (kDebugMode) {
      //   print('API Response for ${request.url}:');
      //   print('Status Code: ${response.statusCode}');
      //   print('Body: ${response.bodyString}');
      // }
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

  // --- Custom GET method with query parameters ---
  @override // Added @override for clarity, though not strictly necessary if signature matches
  Future<Response<T>> get<T>(
    String? url, { // Changed to nullable String?
    Map<String, String>? params,
    Map<String, String>? headers,
    String? contentType,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
  }) {
    final Map<String, String> finalHeaders = {...?headers};

    Uri uri = Uri.parse(url ?? ''); // Handle potential null URL
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...params});
    }

    return super.get(
      uri.toString(),
      headers: finalHeaders,
      contentType: contentType,
      query: query,
      decoder: decoder,
    );
  }

  // --- Method to send POST requests with JSON body ---
  @override
  Future<Response<T>> post<T>(
    String? url, // *** FIX: Changed to nullable String? url ***
    dynamic body, {
    Map<String, String>? headers,
    String? contentType,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
    Progress? uploadProgress,
  }) {
    return super.post(
      url,
      body,
      headers: headers,
      contentType: contentType,
      query: query,
      decoder: decoder,
      uploadProgress: uploadProgress,
    );
  }

  // --- New method to send POST requests with Multipart Form Data (for files) ---
  Future<Response<T>> postFormData<T>(
    String
    url, // This is a new method, so its 'url' parameter doesn't need to match GetConnect.post
    FormData formData, {
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
    Progress? uploadProgress,
  }) {
    return super.post(
      url,
      formData,
      headers: headers,
      query: query,
      decoder: decoder,
      uploadProgress: uploadProgress,
    );
  }
}
