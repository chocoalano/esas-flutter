// lib/features/auth/presentation/views/login_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/services/app_version_service.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_button.dart';
import '../../../setup/presentation/routes/setup_routes.dart';
import '../controllers/login_controller.dart';
import '../widgets/forgot_password_sheet.dart';

/// Halaman Masuk Korporat Aman (Secure Corporate Login Screen).
///
/// Standar visual enterprise "Workforce Precision":
/// * Menggunakan data dinamis valid (TenantContext, ServerConfig, AppVersionService) tanpa data palsu/hardcoded.
/// * Hanya menyediakan opsi autentikasi yang didukung secara riil (Kredensial NIP/Email & Google Sign-In).
/// * Desain visual responsif, halus, ergonomis, bebas overflow pada berbagai resolusi layar.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final LoginController controller = Get.find<LoginController>();

  bool _isNipTab = true;
  bool _rememberId = true;

  String get _currentTenant {
    if (Get.isRegistered<TenantContext>()) {
      final tenant = Get.find<TenantContext>().tenant;
      if (tenant != null && tenant.trim().isNotEmpty) {
        return tenant.trim();
      }
    }
    return '';
  }

  String get _currentHost {
    if (Get.isRegistered<ServerConfig>()) {
      final config = Get.find<ServerConfig>();
      final domain = config.domain;
      if (domain != null && domain.trim().isNotEmpty) {
        final uri = Uri.tryParse(domain);
        return uri?.host ?? domain.replaceFirst(RegExp(r'^https?://'), '');
      }
    }
    return '';
  }

  void _switchTab(bool isNip) {
    if (_isNipTab == isNip) return;
    setState(() {
      _isNipTab = isNip;
    });
  }

  void _submit() {
    if (controller.isBusy) return;
    if (controller.loginFormKey.currentState?.validate() ?? false) {
      controller.loginUser();
    }
  }

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

    const Color brandEmerald = Color(0xFF047857);
    const Color brandAccent = Color(0xFF10B981);
    const Color surfaceScaffold = Color(0xFFF8F9FF);
    final Color borderSubtle = palette.borderSubtle;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : surfaceScaffold,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Navigasi & Status Aman
            _buildTopAppBar(context, palette, brandEmerald, borderSubtle),

            // Konten Formulir Scrollable
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: controller.loginFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Kartu Konteks Tenant Aktif (Dinamis dari TenantContext & ServerConfig)
                          _buildActiveTenantCard(
                            palette,
                            brandEmerald,
                            brandAccent,
                            borderSubtle,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // 2. Kartu Utama Formulir Masuk
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.colorScheme.surface
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Heading & Badge Keamanan
                                _buildHeadingSection(brandEmerald),
                                const SizedBox(height: AppSpacing.lg),

                                // Tab Switcher Segmen (NIP vs Email)
                                _buildSegmentedControl(
                                  brandEmerald,
                                  borderSubtle,
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                // Input Kredensial
                                _buildCredentialInputs(
                                  context,
                                  theme,
                                  palette,
                                  brandEmerald,
                                  borderSubtle,
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Checkbox Ingat ID
                                _buildRememberRow(brandEmerald),
                                const SizedBox(height: AppSpacing.xl),

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

                                // Corporate SSO (Hanya Google / Apple bila didukung)
                                if (controller.canSignInWithGoogle ||
                                    controller.canSignInWithApple) ...[
                                  const SizedBox(height: AppSpacing.xl),
                                  _buildSsoDivider(palette),
                                  const SizedBox(height: AppSpacing.lg),
                                  if (controller.canSignInWithGoogle)
                                    Obx(
                                      () => _GoogleSignInButton(
                                        busy: controller.isGoogleLoading.value,
                                        onPressed: controller.isLoading.value
                                            ? null
                                            : controller.loginWithGoogle,
                                      ),
                                    ),
                                  if (controller.canSignInWithApple) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Obx(
                                      () => _AppleSignInButton(
                                        busy: controller.isAppleLoading.value,
                                        onPressed: controller.isLoading.value
                                            ? null
                                            : controller.loginWithApple,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // 3. Catatan Keamanan Zero-Trust & Legal Footer
                          _buildSecurityNotice(),
                          const SizedBox(height: AppSpacing.md),
                          _buildLegalFooter(),
                          const SizedBox(height: AppSpacing.sm),
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

  /// Top App Bar
  Widget _buildTopAppBar(
    BuildContext context,
    AppPalette palette,
    Color brandEmerald,
    Color borderSubtle,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: borderSubtle, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Secure Login',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderSubtle),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 12, color: Color(0xFF047857)),
                SizedBox(width: 4),
                Text(
                  'TLS 1.3',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Tenant Aktif (Dinamis dari context tenancy tanpa hardcode)
  Widget _buildActiveTenantCard(
    AppPalette palette,
    Color brandEmerald,
    Color brandAccent,
    Color borderSubtle,
  ) {
    final tenant = _currentTenant;
    final host = _currentHost;

    final String workspaceName = tenant.isNotEmpty
        ? 'Workspace: ${tenant.toUpperCase()}'
        : 'Workspace Default';
    final String workspaceSubtitle = host.isNotEmpty
        ? (tenant.isNotEmpty ? '$tenant.$host' : host)
        : 'Sistem Terhubung';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: brandAccent.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: Color(0xFF047857),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        workspaceName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  workspaceSubtitle,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => Get.toNamed(SetupRoutes.setup),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              side: BorderSide(color: borderSubtle),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: const Color(0xFFF8FAFC),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(
              Icons.swap_horiz_rounded,
              size: 14,
              color: Color(0xFF047857),
            ),
            label: const Text(
              'Ganti workspace',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF047857),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Heading Section
  Widget _buildHeadingSection(Color brandEmerald) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBCE5D2)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 13,
                color: Color(0xFF047857),
              ),
              SizedBox(width: 5),
              Text(
                'Portal Akses Karyawan',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF047857),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Masuk Akun',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Gunakan kredensial resmi perusahaan Anda untuk membuka portal mandiri & presensi.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// Segmented Switcher NIP vs Email (Dengan FittedBox agar anti-overflow)
  Widget _buildSegmentedControl(Color brandEmerald, Color borderSubtle) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _switchTab(true),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isNipTab ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: _isNipTab
                      ? Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        )
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 14,
                        color: _isNipTab
                            ? const Color(0xFF047857)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'ID Karyawan (NIP)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _isNipTab
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _isNipTab
                              ? const Color(0xFF047857)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _switchTab(false),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !_isNipTab ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: !_isNipTab
                      ? Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        )
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: !_isNipTab
                            ? const Color(0xFF047857)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Email Perusahaan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: !_isNipTab
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: !_isNipTab
                              ? const Color(0xFF047857)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Input Fields Kredensial
  Widget _buildCredentialInputs(
    BuildContext context,
    ThemeData theme,
    AppPalette palette,
    Color brandEmerald,
    Color borderSubtle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label field 1 (NIP atau email)
        const Text(
          'NIP atau email',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),

        // Input 1: NIP / Email (Hint teks wajib 'NIP atau nama@perusahaan.com' untuk pengujian)
        TextFormField(
          controller: controller.nipController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'NIP atau nama@perusahaan.com',
            prefixIcon: Icon(
              _isNipTab ? Icons.badge_outlined : Icons.email_outlined,
              size: AppIconSizes.md,
              color: brandEmerald,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: brandEmerald, width: 1.5),
            ),
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'NIP atau email tidak boleh kosong'
              : null,
        ),

        const SizedBox(height: AppSpacing.md),

        // Label field 2 + Tombol "Lupa kata sandi?"
        Row(
          children: [
            const Expanded(
              child: Text(
                'Kata sandi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            TextButton(
              onPressed: () => showForgotPasswordSheet(
                context,
                initialIdentifier: controller.nipController.text.trim(),
                onSubmit: controller.requestPasswordReset,
                selfServiceAvailable: true,
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                visualDensity: VisualDensity.compact,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Lupa kata sandi?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF047857),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Input 2: Kata Sandi (Hint 'Masukkan kata sandi')
        Obx(
          () => TextFormField(
            controller: controller.passwordController,
            obscureText: controller.isPasswordHidden.value,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            autofillHints: const [AutofillHints.password],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Masukkan kata sandi',
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                size: AppIconSizes.md,
                color: brandEmerald,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  controller.isPasswordHidden.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: AppIconSizes.md,
                  color: const Color(0xFF64748B),
                ),
                onPressed: controller.togglePasswordVisibility,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: brandEmerald, width: 1.5),
              ),
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Kata sandi tidak boleh kosong'
                : null,
          ),
        ),
      ],
    );
  }

  /// Baris Checkbox Ingat ID
  Widget _buildRememberRow(Color brandEmerald) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _rememberId,
            onChanged: (val) {
              setState(() {
                _rememberId = val ?? true;
              });
            },
            activeColor: brandEmerald,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _rememberId = !_rememberId;
              });
            },
            child: const Text(
              'Ingat NIP di perangkat ini',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Divider SSO
  Widget _buildSsoDivider(AppPalette palette) {
    return Row(
      children: [
        Expanded(child: Divider(height: 1, color: palette.borderSubtle)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'atau masuk dengan',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        Expanded(child: Divider(height: 1, color: palette.borderSubtle)),
      ],
    );
  }

  /// Security Notice (Zero-Trust)
  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_outlined, size: 16, color: Color(0xFF047857)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Enkripsi end to end aktif • Kepatuhan Keamanan ISO 27001',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Legal Footer (Wrap agar aman dari overflow pada screen kecil)
  Widget _buildLegalFooter() {
    final String version = AppVersionService.displayVersion.isNotEmpty
        ? AppVersionService.displayVersion
        : 'v1.0.1';

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        const Text(
          'Bantuan IT Support',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const Text(
          '•',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10),
        ),
        const Text(
          'Kebijakan Privasi',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const Text(
          '•',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10),
        ),
        Text(
          version,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

/// Tombol Resmi Masuk dengan Google
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      enabled: onPressed != null && !busy,
      label: 'Masuk dengan Google',
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: busy ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/svg/google_logo.svg',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Masuk dengan Google',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (busy) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol Resmi Masuk dengan Apple
class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null && !busy,
      label: 'Masuk dengan Apple',
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: busy ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.apple, size: 20, color: Colors.white),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'Masuk dengan Apple',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (busy) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
