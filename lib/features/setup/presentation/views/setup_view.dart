import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_section_header.dart';
import '../controllers/setup_controller.dart';

/// The screen a handset is set up on, before anybody signs in.
///
/// It asks the two things a request needs before the right company's database
/// can answer it — the platform's address, and which company on it — and
/// confirms both against the server rather than storing them and hoping. What it
/// deliberately does not ask for is a password: which workspace a handset
/// belongs to is a deployment fact, decided once, by whoever hands the phone
/// over.
///
/// Layar ini punya tiga keadaan dan sebelumnya hanya menggambar dua: berhasil
/// dan gagal. Keadaan ketiga — belum pernah diuji — adalah keadaan yang
/// sebenarnya dilihat setiap orang saat layar dibuka, dan ia dulu berupa ruang
/// kosong. Sekarang ketiganya bernada, berbingkai, dan mengatakan apa langkah
/// berikutnya.
class SetupView extends GetView<SetupController> {
  const SetupView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Konfigurasi Workspace'),
        automaticallyImplyLeading: controller.isReconfiguring,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tanda tempat, bukan hiasan: kotak bergaris yang sama
                    // dengan tanda brand di layar masuk, supaya kedua layar
                    // pertama aplikasi ini terbaca sebagai satu keluarga.
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: AppRadii.xlAll,
                          border: Border.all(color: theme.palette.borderSubtle),
                        ),
                        child: Icon(
                          Icons.apartment_outlined,
                          size: AppIconSizes.xxl,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Hubungkan ke workspace',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Setiap perusahaan punya database dan subdomain sendiri. '
                      'Isi alamat server dan kode workspace, lalu uji '
                      'koneksinya sebelum masuk.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    TextFormField(
                      controller: controller.domainController,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Alamat server',
                        hintText: 'hrms.perusahaan.co.id',
                        helperText:
                            'Alamat platform, tanpa kode workspace di depannya.',
                        helperMaxLines: 2,
                        prefixIcon: Icon(
                          Icons.language_outlined,
                          size: AppIconSizes.xl,
                        ),
                      ),
                      validator: controller.validateDomain,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    TextFormField(
                      controller: controller.workspaceController,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      onFieldSubmitted: (_) => controller.check(),
                      decoration: const InputDecoration(
                        labelText: 'Kode workspace',
                        hintText: 'acme',
                        helperText:
                            'Subdomain perusahaan Anda. Tanya HR bila belum tahu.',
                        helperMaxLines: 2,
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          size: AppIconSizes.xl,
                        ),
                      ),
                      validator: controller.validateWorkspace,
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    const _SubdomainSwitch(),
                    const SizedBox(height: AppSpacing.md),
                    const _AddressPreview(),
                    const SizedBox(height: AppSpacing.xxl),

                    Obx(
                      () => AppButton(
                        label: controller.isChecking.value
                            ? 'Menghubungi server…'
                            : 'Uji koneksi',
                        icon: Icons.wifi_tethering_rounded,
                        busy: controller.isChecking.value,
                        onPressed: controller.check,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    const _Outcome(),

                    if (controller.isReconfiguring) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Batal',
                        variant: AppButtonVariant.text,
                        onPressed: controller.cancel,
                      ),
                    ],
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

/// The subdomain switch, and the reason it is sometimes unavailable.
class _SubdomainSwitch extends GetView<SetupController> {
  const _SubdomainSwitch();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      // Rebuilt as the address is typed: an IP cannot carry a workspace on its
      // front, so the switch turns itself off and says why rather than offering
      // a host that resolves to nothing.
      controller.edits.value;

      final available = controller.supportsSubdomain;

      return SwitchListTile.adaptive(
        value: controller.usesSubdomain,
        onChanged: available
            ? (value) => controller.subdomainMode.value = value
            : null,
        contentPadding: EdgeInsets.zero,
        title: const Text('Workspace punya subdomain sendiri'),
        subtitle: Text(
          !available
              ? 'Tidak bisa diaktifkan untuk alamat IP — "acme.172.16.2.233" '
                    'bukan nama host. Workspace tetap dikirim lewat header '
                    'X-Tenant, jadi aplikasi tetap berfungsi.'
              : controller.subdomainMode.value
              ? 'Aplikasi menghubungi {workspace}.{alamat server}. '
                    'Ini mode standar platform.'
              : 'Aplikasi menghubungi alamat server apa adanya dan menyebut '
                    'workspace lewat header. Untuk server tanpa sertifikat '
                    'wildcard, atau emulator.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.palette.textMuted,
          ),
        ),
        isThreeLine: true,
      );
    });
  }
}

/// Where a request would actually go, and whether it would be encrypted.
///
/// Alamatnya digambar di dalam sumur bergaris dengan angka tabular. Sebelumnya
/// ia meminta `fontFamily: 'monospace'` — Flutter menerima satu nama keluarga,
/// bukan tumpukan seperti CSS, sehingga pratinjau alamat diam-diam jatuh ke
/// font proporsional pada sebagian perangkat.
class _AddressPreview extends GetView<SetupController> {
  const _AddressPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Obx(() {
      controller.edits.value;

      final insecure = controller.isInsecure;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Alamat yang dihubungi',
            dense: true,
            padding: EdgeInsets.only(bottom: AppSpacing.tight),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.snug,
            ),
            decoration: BoxDecoration(
              color: palette.surfaceSubtle,
              borderRadius: AppRadii.mdAll,
              border: Border.all(color: palette.borderSubtle),
            ),
            child: SelectableText(
              controller.preview,
              style: AppTypography.mono(
                color: insecure
                    ? palette.danger.foreground
                    : theme.colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
          if (insecure) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_open_rounded,
                  size: AppIconSizes.md,
                  color: palette.danger.foreground,
                ),
                const SizedBox(width: AppSpacing.tight),
                Expanded(
                  child: Text(
                    'Alamat ini tidak terenkripsi. Kata sandi dan data karyawan '
                    'akan dikirim tanpa perlindungan.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.danger.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    });
  }
}

/// What the server said — the confirmation the screen exists to show, or the
/// refusal it exists to explain.
class _Outcome extends GetView<SetupController> {
  const _Outcome();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).palette;

    return Obx(() {
      final name = controller.confirmedName.value;
      final error = controller.checkError.value;

      if (controller.isChecking.value) {
        return _Banner(
          tone: palette.info,
          icon: Icons.wifi_tethering_rounded,
          title: 'Sedang memeriksa',
          message:
              'Aplikasi menghubungi alamat di atas dan menanyakan apakah '
              'workspace itu ada di sana.',
        );
      }

      if (error != null) {
        return _Banner(
          tone: palette.danger,
          icon: Icons.error_outline_rounded,
          title: 'Belum terhubung',
          message: error,
        );
      }

      // Keadaan ketiga, yang dulu berupa ruang kosong: alamatnya sudah diketik
      // tetapi belum pernah dijawab siapa pun. Membiarkannya kosong membuat
      // layar ini tampak seolah tinggal ditekan lanjut.
      if (name == null) {
        return _Banner(
          tone: palette.neutral,
          icon: Icons.help_outline_rounded,
          title: 'Belum diuji',
          message:
              'Tekan "Uji koneksi" untuk memastikan alamat dan kode workspace '
              'benar sebelum masuk.',
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Banner(
            tone: palette.success,
            icon: Icons.verified_rounded,
            title: 'Terhubung ke $name',
            message:
                'Pastikan ini perusahaan Anda sebelum melanjutkan. Bila bukan, '
                'perbaiki kode workspace dan uji ulang.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Lanjut masuk',
            icon: Icons.arrow_forward_rounded,
            onPressed: controller.proceed,
          ),
        ],
      );
    });
  }
}

/// Satu blok keadaan, bernada.
///
/// Nadanya datang dari [AppTone], bukan dari `colorScheme.primary` dengan alpha
/// yang dihitung di tempat: hijau brand adalah warna "bisa ditindak", dan
/// memakainya sebagai warna "berhasil" membuat kedua arti itu bertukar tempat
/// pada layar yang juga punya tombol brand.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
  });

  final AppTone tone;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: AppRadii.xlAll,
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSizes.xxl, color: tone.foreground),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tone.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
