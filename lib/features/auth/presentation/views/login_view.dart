// lib/features/auth/presentation/views/login_view.dart
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_button.dart';
import 'package:esas/core/ui/components/app_input_decoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../setup/presentation/routes/setup_routes.dart';
import '../controllers/login_controller.dart';
import '../widgets/forgot_password_sheet.dart';

/// Layar masuk (Login Screen).
///
/// Dirancang dengan estetika enterprise modern yang elegan dan presisi:
/// * **Form Card Container**: Menghindari formulir melayang tanpa batas di atas layar kosong,
///   dibingkai rapi dengan kartu bergaris halus ([AppPalette.borderSubtle]) dan lebar
///   maksimum 440px agar tetap proporsional di tablet maupun ponsel.
/// * **Hierarki Visual Jelas**: Dilengkapi tanda brand resmi, lencana keamanan semantik,
///   serta tipografi berkontras tinggi yang nyaman dibaca.
/// * **Ritme & Kecepatan**: Alur input dirancang cepat tanpa distraksi bagi karyawan yang
///   sedang terburu-buru absen, dengan autofill, aksi 'selesai' di keyboard, serta tombol
///   aksi berkondisi sibuk (busy indicator).
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final isDark = theme.brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient subtle glow di bagian atas
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 340,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.brandGlow.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),

            // Form Konten Utama
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadii.xxlAll,
                      border: Border.all(color: palette.borderSubtle),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Form(
                      key: controller.loginFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header Baris: Logo Brand + Badge Status
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: palette.surfaceRaised,
                                  borderRadius: AppRadii.xlAll,
                                  border: Border.all(
                                    color: palette.borderSubtle,
                                  ),
                                ),
                                child: Image.asset(
                                  'assets/images/logo-square.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.badge_outlined,
                                    color: theme.colorScheme.primary,
                                    size: AppIconSizes.md,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Scales down rather than overflow on a 320dp
                              // phone with large text.
                              const Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: AppBadge(
                                    label: 'PORTAL RESMI',
                                    tone: AppBadgeTone.brand,
                                    icon: Icons.shield_outlined,
                                    size: AppBadgeSize.small,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          Text(
                            'Masuk sekarang',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Gunakan NIP atau email dan kata sandi yang terdaftar di sistem.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.textMuted,
                              height: 1.45,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),
                          Divider(height: 1, color: palette.borderSubtle),
                          const SizedBox(height: AppSpacing.xl),

                          // Field: NIP atau email (FUNC-C03). The server
                          // accepts either, and a NIP may carry letters, so
                          // the keyboard is text and nothing is filtered out.
                          const AppFieldLabel('NIP atau email', required: true),
                          TextFormField(
                            controller: controller.nipController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            decoration: const InputDecoration(
                              hintText: 'NIP atau nama@perusahaan.com',
                              prefixIcon: Icon(
                                Icons.badge_outlined,
                                size: AppIconSizes.lg,
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'NIP atau email tidak boleh kosong'
                                : null,
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Field: Kata Sandi
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(
                                child: AppFieldLabel(
                                  'Kata sandi',
                                  required: true,
                                ),
                              ),
                              Flexible(
                                child: TextButton(
                                onPressed: () => showForgotPasswordSheet(
                                  context,
                                  initialIdentifier:
                                      controller.nipController.text.trim(),
                                  onSubmit: controller.requestPasswordReset,
                                  // The server offers a reset link to a verified email
                                  // (PO 4.3); everyone else is still pointed to HR.
                                  selfServiceAvailable: true,
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Lupa kata sandi?',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ),
                            ],
                          ),
                          Obx(
                            () => TextFormField(
                              controller: controller.passwordController,
                              obscureText: controller.isPasswordHidden.value,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                hintText: 'Masukkan kata sandi',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
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
                                  onPressed:
                                      controller.togglePasswordVisibility,
                                ),
                              ),
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                  ? 'Kata sandi tidak boleh kosong'
                                  : null,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xxl),

                          // Tombol Masuk Utama
                          Obx(
                            () => AppButton(
                              label: 'Masuk',
                              icon: Icons.login_rounded,
                              busy: controller.isLoading.value,
                              onPressed: controller.isGoogleLoading.value
                                  ? null
                                  : _submit,
                            ),
                          ),

                          // Opsi Masuk Google (jika Firebase aktif)
                          if (controller.canSignInWithGoogle ||
                              controller.canSignInWithApple) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    height: 1,
                                    color: palette.borderSubtle,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  child: Text(
                                    'atau',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: palette.textMuted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    height: 1,
                                    color: palette.borderSubtle,
                                  ),
                                ),
                              ],
                            ),
                            if (controller.canSignInWithGoogle) ...[
                              const SizedBox(height: AppSpacing.lg),
                              Obx(
                                () => _GoogleSignInButton(
                                  busy: controller.isGoogleLoading.value,
                                  onPressed: controller.isLoading.value ||
                                          controller.isAppleLoading.value
                                      ? null
                                      : controller.loginWithGoogle,
                                ),
                              ),
                            ],
                            if (controller.canSignInWithApple) ...[
                              const SizedBox(height: AppSpacing.md),
                              Obx(
                                () => _AppleSignInButton(
                                  busy: controller.isAppleLoading.value,
                                  onPressed: controller.isLoading.value ||
                                          controller.isGoogleLoading.value
                                      ? null
                                      : controller.loginWithApple,
                                ),
                              ),
                            ],
                          ],

                          const SizedBox(height: AppSpacing.xl),

                          // Jaminan Keamanan Kredensial
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceSubtle,
                              borderRadius: AppRadii.lgAll,
                              border: Border.all(color: palette.borderSubtle),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: AppIconSizes.sm,
                                  color: palette.brandAccent,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Flexible(
                                  child: Text(
                                    'Kredensial disimpan terenkripsi di perangkat ini.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: palette.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Navigasi Pindah/Ganti Workspace
                          Center(
                            child: TextButton.icon(
                              onPressed: () => Get.toNamed(SetupRoutes.setup),
                              icon: const Icon(
                                Icons.swap_horiz_rounded,
                                size: AppIconSizes.md,
                              ),
                              label: const Text('Ganti workspace'),
                              style: TextButton.styleFrom(
                                foregroundColor: palette.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (controller.isBusy) return;
    if (controller.loginFormKey.currentState?.validate() ?? false) {
      controller.loginUser();
    }
  }
}

/// Tombol autentikasi Apple sesuai panduan Human Interface Guidelines Apple.
///
/// Latar hitam pekat + teks putih + ikon Apple — satu-satunya variasi yang
/// diizinkan Apple untuk latar terang maupun gelap tanpa perubahan warna.
class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null && !busy;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isEnabled ? Colors.black : Colors.black54,
        borderRadius: AppRadii.xlAll,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.xlAll,
          onTap: isEnabled ? onPressed : null,
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: AppIconSizes.lg,
                    height: AppIconSizes.lg,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  const Icon(
                    Icons.apple,
                    color: Colors.white,
                    size: AppIconSizes.lg + 4,
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Text(
                  'Masuk dengan Apple',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
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

/// Tombol autentikasi Google resmi dengan branding khas Google.
///
/// Menampilkan ikon multi-warna resmi Google ("G" logo) di atas badge putih kontras,
/// dipadukan dengan warna khas Google Blue (`#4285F4`) dan bayangan lembut.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

  static const Color _googleBlue = Color(0xFF4285F4);
  static const Color _googleBluePressed = Color(0xFF3367D6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null && !busy;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isEnabled ? _googleBlue : _googleBlue.withValues(alpha: 0.55),
        borderRadius: AppRadii.xlAll,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.xlAll,
          onTap: isEnabled ? onPressed : null,
          splashColor: Colors.white24,
          highlightColor: _googleBluePressed.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: AppIconSizes.lg,
                    height: AppIconSizes.lg,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  // White circular container for the official 4-color Google G logo
                  Container(
                    width: 28,
                    height: 28,
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      'assets/svg/google_logo.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                // Wraps instead of overflowing with large text.
                Flexible(
                  child: Text(
                    'Masuk dengan Google',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
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
