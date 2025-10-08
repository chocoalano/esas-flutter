import 'package:esas/app/modules/profile/profile_pages.dart';
import 'package:esas/app/widgets/controllers/storage_keys.dart';
import 'package:flutter/material.dart'; // Untuk GlobalKey, TextEditingController, Colors
import 'package:get/get.dart';
import 'package:esas/app/services/api_provider.dart'; // Asumsikan ApiProvider Anda ada
import 'package:get_storage/get_storage.dart';
import 'dart:convert'; // Import this for jsonDecode

class ProfileChangePasswordController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final GetStorage _storage = GetStorage();

  // GlobalKey for managing form state and triggering validation
  final GlobalKey<FormState> changePasswordFormKey = GlobalKey<FormState>();

  // TextEditingController for each input field
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmNewPasswordController =
      TextEditingController();

  // RxBool for managing password visibility
  final RxBool isCurrentPasswordVisible = false.obs;
  final RxBool isNewPasswordVisible = false.obs;
  final RxBool isConfirmNewPasswordVisible = false.obs;

  // RxBool for loading status during password change process
  final RxBool isLoading = false.obs;

  @override
  void onClose() {
    // Ensure controllers are disposed when no longer needed to prevent memory leaks
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmNewPasswordController.dispose();
    super.onClose();
  }

  // Toggle password visibility
  void toggleCurrentPasswordVisibility() {
    isCurrentPasswordVisible.value = !isCurrentPasswordVisible.value;
  }

  void toggleNewPasswordVisibility() {
    isNewPasswordVisible.value = !isNewPasswordVisible.value;
  }

  void toggleConfirmNewPasswordVisibility() {
    isConfirmNewPasswordVisible.value = !isConfirmNewPasswordVisible.value;
  }

  // --- Form Validation Methods ---

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
    if (value.length < 6) {
      return 'Kata sandi baru minimal 6 karakter.';
    }
    // Add regex for password complexity if necessary
    if (!RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{6,}$',
    ).hasMatch(value)) {
      return 'Password harus mengandung huruf, angka, dan simbol.';
    }
    return null;
  }

  String? validateConfirmNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi kata sandi baru tidak boleh kosong.';
    }
    if (value != newPasswordController.text) {
      return 'Konfirmasi kata sandi tidak cocok dengan kata sandi baru.';
    }
    return null;
  }

  // --- Logic to Change Password ---
  Future<void> changePassword() async {
    // Validate all form fields
    if (changePasswordFormKey.currentState?.validate() ?? false) {
      isLoading(true); // Activate loading

      try {
        final currentPassword = currentPasswordController.text;
        final newPassword = newPasswordController.text;
        final newPasswordConfirmation = confirmNewPasswordController.text;
        final localPass = _storage.read(
          StorageKeys.userPassword,
        ); // Assuming userPassword is stored

        if (localPass == null) {
          _showSnackbar(
            'Error',
            'Kata sandi lokal tidak ditemukan. Mohon login ulang.',
            isError: true,
          );
          return;
        }

        if (currentPassword != localPass) {
          _showSnackbar('Gagal', 'Kata sandi saat ini salah.', isError: true);
          return;
        }

        if (newPassword == localPass) {
          _showSnackbar(
            'Gagal',
            'Kata sandi baru tidak boleh sama dengan kata sandi sebelumnya.',
            isError: true,
          );
          return;
        }

        // Proceed with API call if all local checks pass
        final response = await _apiProvider.post(
          '/general-module/auth/change-password',
          {
            'password':
                currentPassword, // API might expect 'password' for current
            'new_password': newPassword,
            'confirmation_new_password': newPasswordConfirmation,
          },
        );
        // --- FIX START ---
        // Decode the response body string into a Map
        Map<String, dynamic>? resBody;
        try {
          if (response.bodyString != null && response.bodyString!.isNotEmpty) {
            resBody = json.decode(response.bodyString!) as Map<String, dynamic>;
          }
        } catch (e) {
          debugPrint('Error decoding response body: $e');
          // Handle cases where response.bodyString is not valid JSON
          _showSnackbar('Error', 'Respons server tidak valid.', isError: true);
          return; // Exit if response body is not decodable
        }

        debugPrint(
          "API Response Body: $resBody",
        ); // Print decoded body for debugging

        if (response.statusCode == 200) {
          if (resBody != null && resBody['success'] == true) {
            await _storage.write(
              StorageKeys.userPassword,
              newPassword,
            ); // Update local password
            _showSnackbar(
              'Sukses',
              resBody['message'] ??
                  'Kata sandi berhasil diubah!', // Use message from API if available
              isSuccess: true,
            );
            // Clear form after success
            currentPasswordController.clear();
            newPasswordController.clear();
            confirmNewPasswordController.clear();
            Get.offAllNamed(ProfileRoutes.PROFILE);
          } else {
            // API call was 200 OK, but logic indicates failure (e.g., success: false)
            _showSnackbar(
              'Gagal',
              resBody?['message'] ??
                  'Gagal mengubah kata sandi. Respons tidak sesuai.',
              isError: true,
            );
          }
        } else {
          // API call returned non-200 status code
          _showSnackbar(
            'Gagal',
            resBody?['message'] ??
                'Gagal mengubah kata sandi. Status: ${response.statusCode ?? '-'}',
            isError: true,
          );
        }
        // --- FIX END ---
      } catch (e) {
        debugPrint('Error changing password: $e');
        _showSnackbar(
          'Error',
          'Terjadi kesalahan: ${e.toString()}',
          isError: true,
        );
      } finally {
        isLoading(false); // Deactivate loading
      }
    }
  }

  // --- Helper for displaying snackbars using ThemeData ---
  void _showSnackbar(
    String title,
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    Color backgroundColor;
    Color textColor;

    if (isError) {
      backgroundColor = Get.theme.colorScheme.error;
      textColor = Get.theme.colorScheme.onError;
    } else if (isSuccess) {
      backgroundColor = Get
          .theme
          .colorScheme
          .primary; // Or a specific success color if defined in theme
      textColor = Get.theme.colorScheme.onPrimary;
    } else {
      backgroundColor = Get.theme.colorScheme.surface; // Default info color
      textColor = Get.theme.colorScheme.onSurfaceVariant;
    }

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: backgroundColor,
      colorText: textColor,
      margin: const EdgeInsets.all(10),
      borderRadius: 8,
    );
  }
}
