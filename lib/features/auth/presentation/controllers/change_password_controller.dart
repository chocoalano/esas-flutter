import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/services/auth_api_service.dart';

class ChangePasswordController extends GetxController {
  ChangePasswordController({required AuthApiService api}) : _api = api;

  final AuthApiService _api;

  final GlobalKey<FormState> changePasswordFormKey = GlobalKey<FormState>();

  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmNewPasswordController =
      TextEditingController();

  final RxBool isCurrentPasswordVisible = false.obs;
  final RxBool isNewPasswordVisible = false.obs;
  final RxBool isConfirmNewPasswordVisible = false.obs;
  final RxBool isLoading = false.obs;

  @override
  void onClose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmNewPasswordController.dispose();
    super.onClose();
  }

  void toggleCurrentPasswordVisibility() =>
      isCurrentPasswordVisible.value = !isCurrentPasswordVisible.value;

  void toggleNewPasswordVisibility() =>
      isNewPasswordVisible.value = !isNewPasswordVisible.value;

  void toggleConfirmNewPasswordVisibility() =>
      isConfirmNewPasswordVisible.value = !isConfirmNewPasswordVisible.value;

  String? validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kata sandi saat ini tidak boleh kosong.';
    }

    return null;
  }

  String? validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kata sandi baru tidak boleh kosong.';
    }

    if (value.length < 8) {
      return 'Kata sandi baru minimal 8 karakter.';
    }

    if (value == currentPasswordController.text) {
      return 'Kata sandi baru tidak boleh sama dengan kata sandi saat ini.';
    }

    return null;
  }

  String? validateConfirmNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi kata sandi tidak boleh kosong.';
    }

    if (value != newPasswordController.text) {
      return 'Konfirmasi kata sandi tidak cocok.';
    }

    return null;
  }

  /// Change the password.
  ///
  /// What this no longer does is compare the typed current password against a
  /// copy of the real one kept in unencrypted local storage. That check was a
  /// security control on the wrong side of the trust boundary, it was the whole
  /// reason the plaintext password had to be stored at all (CRIT-03), and it was
  /// also a bug: a password changed on the web portal left the local copy stale,
  /// so the screen rejected the employee's genuine, correct password.
  ///
  /// The server already validates it — `Hash::check` in `AuthRepository::
  /// update_password` — and answers a wrong one with HTTP 200 and
  /// `{success: false, message: 'Password saat ini salah.'}`. That is why the
  /// result is read from `success` rather than from the status code.
  Future<void> changePassword() async {
    if (!(changePasswordFormKey.currentState?.validate() ?? false)) {
      return;
    }

    isLoading.value = true;

    try {
      final body = await _api.changePassword(
        currentPassword: currentPasswordController.text,
        newPassword: newPasswordController.text,
        confirmation: confirmNewPasswordController.text,
      );

      if (body['success'] == true) {
        showSuccessSnackbar(
          body['message']?.toString() ?? 'Kata sandi berhasil diubah!',
        );
        _clearForm();
        return;
      }

      showErrorSnackbar(
        body['message']?.toString() ?? 'Gagal mengubah kata sandi.',
        title: 'Gagal',
      );
    } on ApiException catch (error) {
      showErrorSnackbar(error.firstFieldError ?? error.message);
    } finally {
      isLoading.value = false;
    }
  }

  void _clearForm() {
    currentPasswordController.clear();
    newPasswordController.clear();
    confirmNewPasswordController.clear();
  }
}
