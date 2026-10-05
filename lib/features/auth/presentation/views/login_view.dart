// lib/features/auth/presentation/views/login_view.dart
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_button.dart';
import 'package:esas/core/ui/components/app_input_decoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/login_controller.dart';

/// Layar masuk.
///
/// Satu kolom, rata kiri, dengan lebar maksimum 420px supaya di tablet baris
/// tidak melebar sampai sulit dibaca. Tidak ada ilustrasi dan tidak ada kartu
/// mengambang: layar ini punya satu tugas, dan setiap elemen yang tidak
/// membantu menyelesaikannya hanya menunda orang yang sedang terburu-buru absen
/// pagi.
///
/// Yang menggantikan hiasan adalah ritme: tanda brand, judul, satu garis 1px
/// yang memisahkan penjelasan dari formulir, lalu dua field dengan jarak yang
/// sama persis. Garis itu bukan dekorasi — ia penanda tempat layar berhenti
/// menjelaskan dan mulai meminta.
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xxxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: controller.loginFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tanda brand, bukan hiasan: memberi tahu aplikasi mana
                    // yang sedang meminta kata sandi.
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: AppRadii.xlAll,
                        border: Border.all(color: palette.borderSubtle),
                      ),
                      child: Image.asset(
                        'assets/images/logo-square.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.badge_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    Text(
                      'Masuk ke ESAS',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Gunakan NIP dan kata sandi yang diberikan oleh HR.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    Divider(height: 1, color: palette.borderSubtle),
                    const SizedBox(height: AppSpacing.xxl),

                    const AppFieldLabel('NIP', required: true),
                    TextFormField(
                      controller: controller.nipController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        hintText: '1234567890',
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          size: AppIconSizes.lg,
                        ),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'NIP tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    const AppFieldLabel('Kata sandi', required: true),
                    Obx(
                      () => TextFormField(
                        controller: controller.passwordController,
                        obscureText: controller.isPasswordHidden.value,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        // Menekan "selesai" di papan ketik langsung mengirim,
                        // jadi tangan tidak perlu berpindah ke tombol.
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Masukkan kata sandi',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            size: AppIconSizes.lg,
                          ),
                          suffixIcon: IconButton(
                            tooltip: controller.isPasswordHidden.value
                                ? 'Tampilkan kata sandi'
                                : 'Sembunyikan kata sandi',
                            icon: Icon(
                              controller.isPasswordHidden.value
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: AppIconSizes.lg,
                            ),
                            onPressed: controller.togglePasswordVisibility,
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Kata sandi tidak boleh kosong'
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Label tetap dirender sebagai teks selama pengiriman:
                    // detik ketika seseorang paling ingin tahu tombol mana yang
                    // barusan ia tekan adalah detik yang paling buruk untuk
                    // menghilangkan namanya.
                    Obx(
                      () => AppButton(
                        label: 'Masuk',
                        busy: controller.isLoading.value,
                        onPressed: _submit,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: AppIconSizes.xs,
                          color: palette.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.tight),
                        Flexible(
                          child: Text(
                            'Kredensial disimpan terenkripsi di perangkat ini.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ),
                      ],
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

  void _submit() {
    if (controller.isLoading.value) return;
    if (controller.loginFormKey.currentState?.validate() ?? false) {
      controller.loginUser();
    }
  }
}
