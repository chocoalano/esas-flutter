import 'dart:async';
import 'dart:io';

import 'package:esas/app/data/Permit/leave_type.m.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/views/snackbar.dart';

class PermitController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final GetStorage _storage = GetStorage();

  final isLoading = false.obs;
  final RxList<LeaveType> leaveTypes = <LeaveType>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchLeaveTypes();
  }

  /// Ambil daftar tipe cuti/perizinan
  Future<void> fetchLeaveTypes() async {
    await _performApiCall<void, List<dynamic>>(
      endpoint: (_) => '/hris-module/permit-types/list',
      onSuccess: _updateLeaveTypes,
    );
  }

  void _updateLeaveTypes(List<dynamic> data) {
    final items = data
        .map((e) => LeaveType.fromJson(e as Map<String, dynamic>))
        .toList();
    leaveTypes.assignAll(items);
  }

  Future<void> _performApiCall<R, T>({
    String? readKey,
    required String Function(R? id) endpoint,
    required void Function(T data) onSuccess,
  }) async {
    isLoading.value = true;
    try {
      R? id;
      if (readKey != null) {
        id = _storage.read<R>(readKey);
        if (id == null) {
          throw PlatformException(
            code: 'NO_ID',
            message: 'ID pengguna tidak tersedia',
          );
        }
      }

      final response = await _apiProvider.get(endpoint(id));
      if (response.statusCode == 200) {
        try {
          onSuccess(response.body as T);
        } catch (e) {
          throw FormatException('Response format tidak sesuai');
        }
      } else {
        _handleApiError(response.statusCode, response.body);
      }
    } on SocketException {
      showErrorSnackbar('Tidak ada koneksi internet.');
    } on TimeoutException {
      showErrorSnackbar('Koneksi terlalu lama.');
    } on FormatException catch (e) {
      showErrorSnackbar(e.message);
    } on PlatformException catch (e) {
      showErrorSnackbar(e.message ?? 'Gagal mendapatkan info perangkat.');
    } catch (e) {
      if (kDebugMode) debugPrint('Unexpected error: $e');
      showErrorSnackbar('Terjadi kesalahan tidak terduga.');
    } finally {
      isLoading.value = false;
    }
  }

  void _handleApiError(int? statusCode, dynamic body) {
    if (kDebugMode) debugPrint('API Error [$statusCode]: $body');

    final message = switch (statusCode) {
      400 => 'Permintaan tidak valid.',
      401 => 'Akses ditolak. Silakan login ulang.',
      403 => 'Anda tidak memiliki izin.',
      404 => 'Data tidak ditemukan.',
      422 => _extractValidationError(body),
      500 => 'Kesalahan server. Coba lagi nanti.',
      _ => 'Error tidak diketahui (kode: \$statusCode).',
    };

    showErrorSnackbar(message);
  }

  String _extractValidationError(dynamic body) {
    if (body is Map && body['errors'] is Map) {
      final errors = body['errors'] as Map;
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        return first.first.toString();
      }
    }
    if (body is Map && body['message'] is String) {
      return body['message'] as String;
    }
    return 'Data tidak valid.';
  }
}
