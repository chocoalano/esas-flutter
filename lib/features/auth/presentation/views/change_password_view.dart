import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_button.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_input_decoration.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/features/profile/presentation/routes/profile_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/change_password_controller.dart';

/// Ubah kata sandi.
///
/// Perubahan yang paling terasa di sini bukan jaraknya, melainkan urutan
/// informasinya. Aturan kata sandi sebelumnya hanya muncul sebagai pesan merah
/// setelah percobaan gagal — jadi orang mengetik delapan karakter, ditolak,
/// mengetik ulang, dan baru pada percobaan ketiga tahu bahwa kata sandi baru
/// tidak boleh sama dengan yang lama. Ketiga syaratnya sekarang tertulis di
/// muka dan mencentang dirinya sendiri sambil diketik; validator di controller
/// tetap menjadi penentu akhir, dan satu pun kalimatnya tidak berubah.
class ChangePasswordView extends GetView<ChangePasswordController> {
  const ChangePasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        Get.offAllNamed(ProfileRoutes.profile);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ubah Kata Sandi'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Get.offAllNamed(ProfileRoutes.profile),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xxl,
              AppSpacing.xxl,
              AppSpacing.bottomSafe,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: controller.changePasswordFormKey,
                // Validasi saat pengguna berinteraksi.
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Perbarui kata sandi Anda untuk menjaga keamanan akun.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    const _PasswordRules(),
                    const SizedBox(height: AppSpacing.xl),

                    Obx(
                      () => TextFormField(
                        controller: controller.currentPasswordController,
                        obscureText: !controller.isCurrentPasswordVisible.value,
                        textInputAction: TextInputAction.next,
                        decoration: appInputDecoration(
                          theme,
                          'Kata Sandi Saat Ini',
                          hintText: 'Masukkan kata sandi Anda saat ini',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            size: AppIconSizes.lg,
                          ),
                          suffixIcon: _VisibilityToggle(
                            visible: controller.isCurrentPasswordVisible.value,
                            onPressed:
                                controller.toggleCurrentPasswordVisibility,
                          ),
                        ),
                        validator: controller.validateCurrentPassword,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Obx(
                      () => TextFormField(
                        controller: controller.newPasswordController,
                        obscureText: !controller.isNewPasswordVisible.value,
                        textInputAction: TextInputAction.next,
                        decoration: appInputDecoration(
                          theme,
                          'Kata Sandi Baru',
                          hintText: 'Masukkan kata sandi baru',
                          prefixIcon: const Icon(
                            Icons.lock_reset_outlined,
                            size: AppIconSizes.lg,
                          ),
                          suffixIcon: _VisibilityToggle(
                            visible: controller.isNewPasswordVisible.value,
                            onPressed: controller.toggleNewPasswordVisibility,
                          ),
                        ),
                        validator: controller.validateNewPassword,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Obx(
                      () => TextFormField(
                        controller: controller.confirmNewPasswordController,
                        obscureText:
                            !controller.isConfirmNewPasswordVisible.value,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => controller.changePassword(),
                        decoration: appInputDecoration(
                          theme,
                          'Konfirmasi Kata Sandi Baru',
                          hintText: 'Ketik ulang kata sandi baru',
                          prefixIcon: const Icon(
                            Icons.check_circle_outline,
                            size: AppIconSizes.lg,
                          ),
                          suffixIcon: _VisibilityToggle(
                            visible:
                                controller.isConfirmNewPasswordVisible.value,
                            onPressed:
                                controller.toggleConfirmNewPasswordVisibility,
                          ),
                        ),
                        validator: controller.validateConfirmNewPassword,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    Obx(
                      () => AppButton(
                        label: 'Ubah Kata Sandi',
                        busy: controller.isLoading.value,
                        onPressed: controller.changePassword,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol mata, satu bentuk untuk ketiga field.
class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: visible ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi',
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: AppIconSizes.lg,
      ),
      onPressed: onPressed,
    );
  }
}

/// Syarat kata sandi, tertulis sebelum diminta dan mencentang dirinya sendiri.
///
/// Sumber kebenarannya tetap validator di controller — panel ini membacanya,
/// tidak menggantikannya. Setiap syarat membawa bentuk ikon yang berbeda selain
/// warnanya, jadi terpenuhi/belum tetap terbaca di layar tergores dan pada mata
/// yang tidak membedakan hijau dari abu.
class _PasswordRules extends GetView<ChangePasswordController> {
  const _PasswordRules();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.currentPasswordController,
        controller.newPasswordController,
        controller.confirmNewPasswordController,
      ]),
      builder: (context, _) {
        final String current = controller.currentPasswordController.text;
        final String next = controller.newPasswordController.text;
        final String confirmation =
            controller.confirmNewPasswordController.text;

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(
                title: 'Syarat kata sandi baru',
                dense: true,
              ),
              _RuleLine(label: 'Minimal 8 karakter', met: next.length >= 8),
              _RuleLine(
                label: 'Berbeda dari kata sandi saat ini',
                met: next.isNotEmpty && next != current,
              ),
              _RuleLine(
                label: 'Konfirmasi sama persis',
                met: confirmation.isNotEmpty && confirmation == next,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.tight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: AppIconSizes.md,
            color: met ? palette.success.foreground : palette.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: met ? theme.colorScheme.onSurface : palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
