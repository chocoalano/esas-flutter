import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import 'app_badge.dart';
import 'app_card.dart';
import 'app_sparkline.dart';

/// Kartu satu angka: nilai besar bertabular, labelnya, dan pembandingnya.
///
/// Tidak ada angka besar yang mengambang tanpa skala di aplikasi ini. Karena
/// itu kartu ini menyediakan tiga bentuk pembanding sekaligus — chip selisih,
/// keterangan sebaris, dan garis tren — dan setidaknya salah satunya hampir
/// selalu pantas diisi. Sebuah "12" tanpa keterangan tidak bisa dinilai
/// siapa pun; "12" dengan "+2 dari bulan lalu" bisa.
///
/// Konstruktor [AppMetricTile.count] menaikkan angkanya dari nol selama
/// [AppDurations.slow]. Gerak itu satu-satunya yang ditambahkan bahasa visual
/// ini di luar transisi, dan ia membawa nilai: mata menangkap bahwa angkanya
/// baru saja dihitung ulang. Nilai berupa jam atau teks memakai konstruktor
/// biasa — jam yang berhitung naik dari 00:00 hanya akan membingungkan.
class AppMetricTile extends StatelessWidget {
  const AppMetricTile({
    super.key,
    required this.label,
    required String this.value,
    this.unit,
    this.icon,
    this.delta,
    this.deltaTone = AppBadgeTone.neutral,
    this.caption,
    this.trend,
    this.trendSummary,
    this.onTap,
  }) : count = null,
       countFractionDigits = 0,
       assert(
         trend == null || trendSummary != null,
         'Sparkline wajib membawa ringkasan teks.',
       );

  const AppMetricTile.count({
    super.key,
    required this.label,
    required num this.count,
    this.countFractionDigits = 0,
    this.unit,
    this.icon,
    this.delta,
    this.deltaTone = AppBadgeTone.neutral,
    this.caption,
    this.trend,
    this.trendSummary,
    this.onTap,
  }) : value = null,
       assert(
         trend == null || trendSummary != null,
         'Sparkline wajib membawa ringkasan teks.',
       );

  /// Nama metrik. Dirender dalam huruf kapital sebagai micro-label.
  final String label;

  /// Nilai siap tampil, misalnya "08:11". Null pada varian [AppMetricTile.count].
  final String? value;

  /// Nilai numerik yang dihitung naik. Null pada varian biasa.
  final num? count;

  final int countFractionDigits;

  /// Satuan kecil di samping angka, misalnya "hari" atau "mnt".
  final String? unit;

  final IconData? icon;

  /// Selisih terhadap pembanding, misalnya "+2".
  final String? delta;

  final AppBadgeTone deltaTone;

  /// Keterangan sebaris di bawah label, misalnya "dari 22 hari kerja".
  final String? caption;

  /// Deret tren opsional; `null` di dalamnya memutus garis.
  final List<double?>? trend;

  /// Ringkasan teks tren. Wajib bila [trend] diisi.
  final String? trendSummary;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final TextStyle valueStyle = AppTypography.dataLarge(
      color: theme.colorScheme.onSurface,
    );

    Widget valueText(String text) => Text(
      text,
      style: valueStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final num? count = this.count;
    final Widget valueWidget = count == null
        ? valueText(value!)
        : TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: count.toDouble()),
            duration: AppDurations.slow,
            curve: AppMotion.standard,
            builder: (context, animated, _) =>
                valueText(animated.toStringAsFixed(countFractionDigits)),
          );

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null || delta != null) ...[
            Row(
              children: [
                if (icon != null) AppIconBox(icon: icon!, size: 28),
                const Spacer(),
                if (delta != null)
                  Flexible(
                    child: AppBadge(
                      label: delta!,
                      tone: deltaTone,
                      size: AppBadgeSize.small,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.snug),
          ],
          // `FittedBox` dan bukan `Flexible` pada masing-masing anak.
          //
          // Satuan di sini tidak pernah punya faktor flex, jadi sebuah ubin
          // sempit — tiga ubin berdampingan di layar 320dp, atau skala teks 1,3
          // pada dua ubin — membuat baris ini meluap. Membungkus keduanya
          // dengan `Flexible` memindahkan masalahnya alih-alih menutupnya:
          // ketika ruangnya kurang, angkanya ikut dipotong, dan `2…` untuk 21
          // hari kerja adalah angka yang SALAH, bukan angka yang sempit.
          //
          // Menyusut bersama-sama menjaga keduanya tetap benar dan tetap pada
          // satu garis dasar. Ketika ruangnya cukup — dan itu keadaan biasa —
          // tidak ada yang berubah sama sekali.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                valueWidget,
                if (unit != null) ...[
                  const SizedBox(width: AppSpacing.tight),
                  Text(
                    unit!,
                    maxLines: 1,
                    style: AppTypography.dataSmall(color: palette.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (trend != null) ...[
            const SizedBox(height: AppSpacing.snug),
            AppSparkline(values: trend!, summary: trendSummary!),
          ],
        ],
      ),
    );
  }
}
