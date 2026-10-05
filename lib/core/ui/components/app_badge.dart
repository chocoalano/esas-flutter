import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Nada semantik sebuah lencana.
enum AppBadgeTone { neutral, brand, success, warning, danger, info }

/// Ukuran sebuah lencana. Diserap dari `app_status_badge.dart` supaya hanya ada
/// satu tangga ukuran lencana di aplikasi ini, bukan dua yang saling menyalip.
enum AppBadgeSize { small, medium, large }

/// Lencana status: isian tipis, garis 1px, teks berwarna penuh.
///
/// Aplikasi ini sebelumnya menyampaikan status sebagai kalimat berwarna
/// ("Status: Disetujui" dalam huruf hijau). Sebuah lencana memisahkan nilai
/// dari labelnya, jadi mata bisa memindai satu kolom status tanpa membaca
/// kalimat-kalimatnya.
///
/// Isian pekat tidak pernah menjadi varian di sini: [AppTone] sudah menyatakan
/// bahwa lencana di aplikasi ini selalu isian sangat tipis, garis sedikit lebih
/// pekat, dan huruf berwarna penuh.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.icon,
    this.dense = false,
    this.size = AppBadgeSize.medium,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  /// Varian rapat untuk dipakai di dalam baris daftar yang sudah padat.
  /// Sinonim dari `size: AppBadgeSize.small`, dipertahankan karena belasan
  /// pemanggil sudah menuliskannya; bila keduanya diberikan, [dense] menang.
  final bool dense;

  final AppBadgeSize size;

  AppBadgeSize get _effectiveSize => dense ? AppBadgeSize.small : size;

  EdgeInsets get _padding => switch (_effectiveSize) {
    AppBadgeSize.small => const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm - 1,
      vertical: AppSpacing.xxs,
    ),
    AppBadgeSize.medium => const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: 3,
    ),
    AppBadgeSize.large => const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.tight,
    ),
  };

  double get _fontSize => switch (_effectiveSize) {
    AppBadgeSize.small => 10.5,
    AppBadgeSize.medium => 11,
    AppBadgeSize.large => 13,
  };

  double get _iconSize => switch (_effectiveSize) {
    AppBadgeSize.small => 11,
    AppBadgeSize.medium => AppIconSizes.xs,
    AppBadgeSize.large => AppIconSizes.sm,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final AppTone colors = tone.resolve(context);

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _iconSize, color: colors.foreground),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          // Label dipotong, bukan dibiarkan meluap: lencana ini dirender dua
          // kali per kartu absensi di dalam kolom selebar sekitar 90dp, jadi
          // satu label status Indonesia yang lebih panjang dari yang ada
          // sekarang sudah cukup untuk menghasilkan overflow di produksi.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.foreground,
                letterSpacing: 0.2,
                fontSize: _fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titik status berukuran 6px. Dipakai saat ruang tidak cukup untuk teks —
/// misalnya penanda notifikasi belum dibaca.
class AppStatusDot extends StatelessWidget {
  const AppStatusDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Nada sebuah lencana sebagai tiga warna yang benar-benar dipakai.
///
/// Dulu pemetaan ini hidup sebagai `switch` di dalam `AppBadge.build`, jadi
/// setiap widget lain yang butuh bidang bernada — panel hari ini di beranda,
/// misalnya — harus menyalinnya. Dua salinan sebuah tabel warna akan berbeda
/// pada perubahan pertama, dan yang terpecah adalah arti nadanya.
extension AppBadgeToneColors on AppBadgeTone {
  AppTone resolve(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return switch (this) {
      AppBadgeTone.neutral => palette.neutral,
      AppBadgeTone.brand => AppTone(
        foreground: theme.colorScheme.primary,
        background: palette.brandSubtle,
        border: theme.colorScheme.primary.withValues(alpha: 0.28),
      ),
      AppBadgeTone.success => palette.success,
      AppBadgeTone.warning => palette.warning,
      AppBadgeTone.danger => palette.danger,
      AppBadgeTone.info => palette.info,
    };
  }
}
