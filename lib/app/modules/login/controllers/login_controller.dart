import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/controllers/storage_keys.dart';
import 'package:esas/app/widgets/views/snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class LoginController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final GetStorage _storage = GetStorage();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  final TextEditingController nipController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();

  final RxBool isLoading = false.obs;
  final RxBool isPasswordHidden = true.obs;

  bool _isDisposed = false;

  @override
  void onClose() {
    _isDisposed = true;
    nipController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    if (_isDisposed) return;
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  Future<String> _getDeviceId() async {
    try {
      if (GetPlatform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
        return androidInfo.id;
      } else if (GetPlatform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios_device';
      }
      return 'unknown_platform_device';
    } on PlatformException catch (e) {
      if (kDebugMode) print('Failed to get device info: ${e.message}');
      return 'device_info_error';
    } catch (e) {
      if (kDebugMode) print('Unexpected error getting device info: $e');
      return 'device_info_general_error';
    }
  }

  bool _validateInput(String nip, String password) {
    if (nip.isEmpty) {
      showWarningSnackbar('NIP tidak boleh kosong.');
      return false;
    }
    if (password.isEmpty) {
      showWarningSnackbar('Kata sandi tidak boleh kosong.');
      return false;
    }
    return true;
  }

  void _handleApiResponseError(int? statusCode, dynamic responseBody) {
    if (kDebugMode) {
      print('API Error - Status: $statusCode, Body: $responseBody');
    }

    String errorMessage;
    switch (statusCode) {
      case 400:
        errorMessage = 'Permintaan tidak valid. Periksa kembali data Anda.';
        break;
      case 401:
        errorMessage = 'NIP/Email atau kata sandi salah. Silakan coba lagi.';
        break;
      case 403:
        errorMessage = 'Akses ditolak. Anda tidak memiliki izin.';
        break;
      case 404:
        errorMessage = 'Endpoint tidak ditemukan. Hubungi administrator.';
        break;
      case 422:
        errorMessage = 'Data tidak valid. Periksa kembali input Anda.';
        if (responseBody is Map && responseBody['message'] != null) {
          errorMessage = responseBody['message'].toString();
        } else if (responseBody is Map && responseBody['errors'] != null) {
          final errors = responseBody['errors'];
          if (errors is Map && errors.isNotEmpty) {
            final firstKey = errors.keys.first;
            if (errors[firstKey] is List && errors[firstKey].isNotEmpty) {
              errorMessage = 'Validasi gagal: ${errors[firstKey][0]}';
            }
          }
        }
        break;
      case 500:
        errorMessage =
            'Terjadi kesalahan di server. Silakan coba beberapa saat lagi.';
        break;
      default:
        errorMessage =
            'Operasi gagal. Kode: ${statusCode ?? 'Tidak Diketahui'}.';
        break;
    }

    showErrorSnackbar(errorMessage);
  }

  Future<void> _saveLoginData({
    required String token,
    required String tokenType,
    required Map<String, dynamic> user,
    required String nip,
    required String password,
    String? avatar,
  }) async {
    await _storage.write(StorageKeys.token, token);
    await _storage.write(StorageKeys.tokenType, tokenType);
    await _storage.write(StorageKeys.userName, user['name']);
    await _storage.write(StorageKeys.userId, user['id']);
    await _storage.write(StorageKeys.userNip, nip);
    await _storage.write(StorageKeys.userPassword, password);
    await _storage.write(StorageKeys.userJson, user);
    await _storage.write(StorageKeys.userAvatar, avatar);

    if (kDebugMode) print('Login data saved to storage.');
  }

  Future<void> clearStorage() async {
    await _storage.remove(StorageKeys.token);
    await _storage.remove(StorageKeys.tokenType);
    await _storage.remove(StorageKeys.userName);
    await _storage.remove(StorageKeys.userId);
    await _storage.remove(StorageKeys.userNip);
    await _storage.remove(StorageKeys.userPassword);
    await _storage.remove(StorageKeys.userJson);
    await _storage.remove(StorageKeys.userAvatar);

    if (kDebugMode) print('All authentication data cleared from storage.');
  }

  Future<void> loginUser() async {
    isLoading.value = true;

    final nip = nipController.text.trim();
    final password = passwordController.text.trim();

    if (!_validateInput(nip, password)) {
      isLoading.value = false;
      return;
    }

    try {
      final deviceId = await _getDeviceId();
      final payload = {
        'nip': nip,
        'password': password,
        'device_info': deviceId,
      };

      final response = await _apiProvider.post(
        '/general-module/auth/login',
        payload,
      );

      if (response.statusCode == 200 && response.body != null) {
        final Map<String, dynamic> data = response.body;
        if (kDebugMode) print("========> response data server : $data");
        await _saveLoginData(
          token: data['token'],
          tokenType: 'Bearer',
          user: data['user'],
          nip: nip,
          password: password,
          avatar: data['user']['avatar'],
        );
        showSuccessSnackbar('Login berhasil!');
        Get.offAllNamed('/home');
      } else {
        _handleApiResponseError(response.statusCode, response.body);
      }
    } on SocketException {
      showErrorSnackbar('Tidak ada koneksi internet. Periksa jaringan Anda.');
    } on TimeoutException {
      showErrorSnackbar('Koneksi terlalu lama. Silakan coba lagi nanti.');
    } on FormatException {
      showErrorSnackbar('Kesalahan format data dari server.');
    } on PlatformException catch (e) {
      showErrorSnackbar('Gagal mendapatkan info perangkat: ${e.message}');
    } catch (e) {
      showErrorSnackbar(
        'Terjadi kesalahan tidak terduga. Mohon coba lagi dan pastikan anda memiliki koneksi internet.',
      );
    } finally {
      isLoading.value = false;
    }
  }
}
