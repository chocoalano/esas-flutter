import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Satu angka yang dibaca sebelum labelnya.
///
/// Anatomi yang sama dipakai setiap metrik di Beranda, dan urutannya bagian
/// dari kontrak: **nilai dulu, label sesudahnya, keterangan paling akhir.**
/// Bagian bawah Beranda pernah menyampaikan semuanya lewat kalimat berukuran
/// sama, dan sebuah dasbor yang menuntut orang membaca untuk tahu angkanya
/// bukan dasbor melainkan laporan.
///
/// Sengaja BUKAN [AppMetricTile]: yang itu membawa kartunya sendiri — garis,
/// radius, padding — dan di sini beberapa metrik duduk di dalam SATU permukaan
/// bersama. Kartu di dalam kartu adalah persis kebisingan yang sedang dikurangi.
class HomeMetric extends StatelessWidget {
  const HomeMetric({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.tone,
    this.icon,
  });

  /// Sudah diformat oleh pemanggil. Widget ini tidak tahu apa-apa tentang
  /// domainnya dan tidak boleh tahu.
  final String value;

  final String label;

  /// Satuan kecil di samping angka: `hari`, `jam`. Ikut mengecil bersama
  /// angkanya, tidak pernah memotongnya.
  final String? unit;

  /// Nada angka. Kosong berarti tinta biasa — dan itu bakunya: warna
  /// disediakan untuk metrik yang benar-benar menuntut perhatian, bukan untuk
  /// setiap angka di layar.
  final AppTone? tone;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;
    final Color ink = tone?.foreground ?? theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: AppIconSizes.md, color: ink),
          const SizedBox(height: AppSpacing.sm),
        ],
        // Angka dan satuannya menyusut BERSAMA-SAMA. Membiarkan keduanya
        // menyusut sendiri-sendiri menghasilkan `1…` untuk 12 hari kerja, yaitu
        // angka yang salah dan bukan angka yang sempit.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value,
                maxLines: 1,
                style: AppTypography.dataDisplay(color: ink, fontSize: 32),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
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
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Bar dua nada untuk dua hitungan yang berbagi satu penyebut.
///
/// Ia hanya sah ketika kedua angkanya benar-benar menjumlah menjadi totalnya —
/// misalnya hari tepat waktu dan hari terlambat yang bersama-sama membentuk
/// hari kerja. Persentase kehadiran TIDAK termasuk: penyebutnya adalah hari
/// kerja yang diharapkan, dan angka itu tidak dikirim server mana pun.
class HomeSplitBar extends StatelessWidget {
  const HomeSplitBar({
    super.key,
    required this.primary,
    required this.secondary,
    required this.primaryTone,
    required this.secondaryTone,
    required this.semanticsLabel,
  });

  final int primary;
  final int secondary;
  final AppTone primaryTone;
  final AppTone secondaryTone;
  final String semanticsLabel;

  static const double _height = 8;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = Theme.of(context).palette;
    final int total = primary + secondary;

    if (total <= 0) return const SizedBox.shrink();

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: AppRadii.pillAll,
        child: SizedBox(
          height: _height,
          child: Row(
            children: <Widget>[
              // `flex` bilangan bulat aman di sini karena kedua nilainya memang
              // hitungan hari — tidak ada pecahan yang bisa dibulatkan hilang.
              Expanded(
                flex: primary,
                child: ColoredBox(color: primaryTone.foreground),
              ),
              if (secondary > 0)
                Expanded(
                  flex: secondary,
                  child: ColoredBox(color: secondaryTone.foreground),
                ),
              if (total == 0)
                Expanded(child: ColoredBox(color: palette.trackSubtle)),
            ],
          ),
        ),
      ),
    );
  }
}
