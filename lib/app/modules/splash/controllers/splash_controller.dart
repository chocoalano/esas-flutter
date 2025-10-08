import 'dart:async';
import 'dart:io';

import 'package:esas/app/widgets/controllers/storage_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../../../services/api_provider.dart';
import '../../../widgets/views/snackbar.dart';

class SplashController extends GetxController {
  // --- Dependencies ---
  final GetStorage _storage = GetStorage();
  final ApiProvider _api = Get.put(ApiProvider());

  /// GlobalKey untuk mengontrol IntroductionScreen.
  final introKey = GlobalKey<IntroductionScreenState>();

  /// Loading state (opsional untuk indikator loading).
  final RxBool isLoading = false.obs;

  // --- Lifecycle ---
  @override
  void onInit() {
    super.onInit();
    _initializeAppFlow();
  }

  /// Mengecek apakah onboarding selesai dan mencoba auto-login
  Future<void> _initializeAppFlow() async {
    final bool autoLoginSuccess = await autoLogin();
    debugPrint("hasil autologin ======> $autoLoginSuccess");
    if (autoLoginSuccess) {
      Get.offAllNamed('/home');
    } else {
      Get.offAllNamed('/login');
    }
  }

  /// Dipanggil jika user menekan "Done" atau "Skip" di onboarding
  void onIntroEnd() {
    _storage.write(StorageKeys.onboardingCompleted, true);
    Get.offAllNamed('/login');
  }

  /// Reset onboarding dan kembali ke halaman awal
  void onBackToIntro() {
    _storage.remove(StorageKeys.onboardingCompleted);
    Get.offAllNamed('/splash');
  }

  /// Melakukan auto-login berdasarkan data lokal
  Future<bool> autoLogin() async {
    isLoading.value = true;
    bool success = false;

    try {
      final String? nip = _storage.read(StorageKeys.userNip);
      final String? password = _storage.read(StorageKeys.userPassword);
      final String? token = _storage.read(StorageKeys.token);

      if (nip == null ||
          password == null ||
          token == null ||
          nip.isEmpty ||
          password.isEmpty ||
          token.isEmpty) {
        debugPrint('Auto-login gagal: data tidak lengkap.');
        return false;
      }

      final isValid = await _validateTokenOnBackend();
      debugPrint("============>> ini hasilnya $isValid");
      if (isValid) {
        showSuccessSnackbar('Selamat datang kembali!');
        success = true;
      } else {
        clearStorage();
        debugPrint('Token tidak valid. Data lokal dibersihkan.');
      }
    } on SocketException {
      showErrorSnackbar('Tidak ada koneksi internet.');
    } on TimeoutException {
      showErrorSnackbar('Koneksi time out.');
    } on FormatException {
      showErrorSnackbar('Format data dari server salah.');
    } on PlatformException catch (e) {
      showErrorSnackbar('Kesalahan perangkat: ${e.message}');
    } catch (e) {
      if (kDebugMode) print('Auto-login error: $e');
      showErrorSnackbar('Terjadi kesalahan saat auto-login.');
    } finally {
      isLoading.value = false;
    }

    return success;
  }

  /// Validasi token ke backend
  Future<bool> _validateTokenOnBackend() async {
    try {
      final response = await _api.get('/general-module/auth');
      if (response.statusCode == 200 && response.body?['user'] != null) {
        _storage.write(StorageKeys.userName, response.body['user']['name']);
        _storage.write(StorageKeys.userId, response.body['user']['id']);
        _storage.write(StorageKeys.userJson, response.body['user']);
        return true;
      }
      return false;
    } catch (_) {}
    return false;
  }

  Future<void> clearStorage() async {
    await _storage.remove(StorageKeys.token);
    await _storage.remove(StorageKeys.tokenType);
    await _storage.remove(StorageKeys.userName);
    await _storage.remove(StorageKeys.userId);
    await _storage.remove(StorageKeys.userNip);
    await _storage.remove(StorageKeys.userPassword);

    if (kDebugMode) print('All authentication data cleared from storage.');
  }
}
