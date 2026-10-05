import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:esas/features/home/presentation/routes/home_routes.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/device_info_service.dart';
import '../../../../utils/notification/firebase_messaging_services.dart';
import '../../data/repositories/auth_repository.dart';

class LoginController extends GetxController {
  LoginController({
    required AuthRepository authRepository,
    required DeviceInfoService deviceInfo,
  }) : _auth = authRepository,
       _deviceInfo = deviceInfo;

  final AuthRepository _auth;
  final DeviceInfoService _deviceInfo;

  final TextEditingController nipController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();

  final RxBool isLoading = false.obs;
  final RxBool isPasswordHidden = true.obs;

  @override
  void onClose() {
    nipController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  Future<void> loginUser() async {
    final nip = nipController.text.trim();
    final password = passwordController.text.trim();

    if (nip.isEmpty) {
      showWarningSnackbar('NIP tidak boleh kosong.');
      return;
    }

    if (password.isEmpty) {
      showWarningSnackbar('Kata sandi tidak boleh kosong.');
      return;
    }

    isLoading.value = true;

    try {
      await _auth.login(
        identifier: nip,
        password: password,
        deviceId: await _deviceInfo.deviceId(),
      );

      showSuccessSnackbar('Login berhasil!');
      // Sesudah masuk, bukan saat aplikasi dibuka: dialog izin muncul ketika
      // orangnya sudah tahu aplikasi apa yang memintanya. Tidak ditunggu, dan
      // hasilnya tidak menentukan keberhasilan masuk.
      unawaited(ensurePushRegisteredIfAvailable());
      Get.offAllNamed(HomeRoutes.home);
    } on ApiException catch (error) {
      // The mapper's default for a 401 is about an expired session, which is
      // the wrong thing to say on the login screen. This is the one place that
      // knows a 401 means the credentials were wrong.
      showErrorSnackbar(
        error.isUnauthenticated
            ? 'NIP/Email atau kata sandi salah. Silakan coba lagi.'
            : error.message,
      );
    } finally {
      isLoading.value = false;
      // The password is used to authenticate and then dropped. It is never
      // written to storage — see CRIT-03 and SessionRepository.
      passwordController.clear();
    }
  }
}
