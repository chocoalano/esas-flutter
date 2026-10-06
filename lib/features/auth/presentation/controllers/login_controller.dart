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
  final RxBool isGoogleLoading = false.obs;
  final RxBool isPasswordHidden = true.obs;

  /// False when Firebase did not come up at boot; the screen then shows only
  /// the NIP form rather than a button that can only fail.
  bool get canSignInWithGoogle => _auth.canSignInWithGoogle;

  /// Either door is mid-flight. Both buttons wait for it, so two sign-ins
  /// cannot race to write the session.
  bool get isBusy => isLoading.value || isGoogleLoading.value;

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
    if (isBusy) return;

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

      _enterApp();
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

  Future<void> loginWithGoogle() async {
    if (isBusy) return;

    isGoogleLoading.value = true;

    try {
      final user = await _auth.loginWithGoogle(
        deviceId: await _deviceInfo.deviceId(),
      );

      // The account picker was closed. They changed their mind; say nothing.
      if (user == null) return;

      _enterApp();
    } on ApiException catch (error) {
      showErrorSnackbar(_googleRefusalMessage(error));
    } finally {
      isGoogleLoading.value = false;
    }
  }

  /// What to say when `POST /auth/firebase` says no.
  ///
  /// The server refuses an unknown Google account the same way login refuses a
  /// wrong password — a 422 on `id_token` carrying Laravel's `auth.failed`,
  /// which this backend has no Indonesian translation for — so that it does
  /// not say whether the address exists. What the person needs to hear is
  /// different, though: their Google account is fine, it is just not the one
  /// HR has on file.
  ///
  /// Any other refusal on `id_token` is the server's own sentence and is shown
  /// as it is: "Akun ini tidak lagi aktif." must not become "not registered".
  /// Matching the English default is a weak signal, and it fails safe — if the
  /// backend gains a translation, its translated sentence is shown instead.
  static String _googleRefusalMessage(ApiException error) {
    const notRegistered =
        'Akun Google ini tidak terdaftar sebagai karyawan. Gunakan email yang '
        'terdaftar di HR, atau masuk dengan NIP.';

    if (error.isUnauthenticated) return notRegistered;

    if (error.isValidationFailure && error.errors.containsKey('id_token')) {
      return error.message.startsWith('These credentials')
          ? notRegistered
          : error.message;
    }

    return error.message;
  }

  void _enterApp() {
    showSuccessSnackbar('Login berhasil!');
    // Sesudah masuk, bukan saat aplikasi dibuka: dialog izin muncul ketika
    // orangnya sudah tahu aplikasi apa yang memintanya. Tidak ditunggu, dan
    // hasilnya tidak menentukan keberhasilan masuk.
    unawaited(ensurePushRegisteredIfAvailable());
    Get.offAllNamed(HomeRoutes.home);
  }
}
