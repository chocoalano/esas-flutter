import 'package:esas/app/modules/profile/profile_pages.dart';
import 'package:esas/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_change_password_controller.dart';

class ProfileChangePasswordView
    extends GetView<ProfileChangePasswordController> {
  const ProfileChangePasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        Get.offAllNamed(ProfileRoutes.PROFILE);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ubah Kata Sandi'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Get.offAllNamed(ProfileRoutes.PROFILE),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: controller.changePasswordFormKey, // Kaitkan GlobalKey ke Form
            autovalidateMode: AutovalidateMode
                .onUserInteraction, // Validasi saat user berinteraksi
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Perbarui kata sandi Anda untuk menjaga keamanan akun.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // --- Input Kata Sandi Saat Ini ---
                Obx(
                  () => TextFormField(
                    controller: controller.currentPasswordController,
                    obscureText: !controller
                        .isCurrentPasswordVisible
                        .value, // Toggle visibilitas
                    decoration: inputDecoration(
                      Theme.of(context),
                      'Kata Sandi Saat Ini',
                      hintText: 'Masukkan kata sandi Anda saat ini',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.isCurrentPasswordVisible.value
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: controller.toggleCurrentPasswordVisibility,
                      ),
                    ),
                    validator:
                        controller.validateCurrentPassword, // Kaitkan validator
                  ),
                ),
                const SizedBox(height: 16),

                // --- Input Kata Sandi Baru ---
                Obx(
                  () => TextFormField(
                    controller: controller.newPasswordController,
                    obscureText: !controller.isNewPasswordVisible.value,
                    decoration: inputDecoration(
                      Theme.of(context),
                      'Kata Sandi Baru',
                      hintText: 'Masukkan kata sandi baru',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.isNewPasswordVisible.value
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: controller.toggleNewPasswordVisibility,
                      ),
                    ),
                    validator: controller.validateNewPassword,
                  ),
                ),
                const SizedBox(height: 16),

                // --- Input Konfirmasi Kata Sandi Baru ---
                Obx(
                  () => TextFormField(
                    controller: controller.confirmNewPasswordController,
                    obscureText: !controller.isConfirmNewPasswordVisible.value,
                    decoration: inputDecoration(
                      Theme.of(context),
                      'Konfirmasi Kata Sandi Baru',
                      hintText: 'Ketik ulang kata sandi baru',
                      prefixIcon: const Icon(Icons.check_circle_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.isConfirmNewPasswordVisible.value
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed:
                            controller.toggleConfirmNewPasswordVisibility,
                      ),
                    ),
                    validator: controller.validateConfirmNewPassword,
                  ),
                ),
                const SizedBox(height: 32),

                // --- Tombol Ubah Kata Sandi ---
                Obx(
                  () => ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null // Nonaktifkan tombol saat loading
                        : controller
                              .changePassword, // Panggil metode perubahan password
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: colorScheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Ubah Kata Sandi',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
