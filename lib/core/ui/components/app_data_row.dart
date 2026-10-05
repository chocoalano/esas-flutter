import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import 'app_badge.dart';

/// Satu baris panel data: micro-label di kolom kiri, nilai monospace di kanan,
/// dan chip selisih opsional.
///
/// Kolom labelnya 96dp dan tidak dipatok mati. Pada skala teks besar — biasa
/// dipakai karyawan yang lebih senior — kolom lebar tetap membuat label panjang
/// membungkus menjadi tiga baris sementara nilainya diam di tempat, dan yang
/// patah justru penjajaran antar baris yang menjadi seluruh alasan panel ini
/// ada. Karena itu begitu ukuran micro-label terskala melewati 14 piksel, label
/// pindah ke atas nilainya. Menumpuk adalah degradasi yang masih terbaca;
/// membungkus tidak.
class AppDataRow extends StatelessWidget {
  const AppDataRow({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
    this.trailing,
    this.delta,
    this.deltaTone = AppBadgeTone.neutral,
    this.labelWidth = 96,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  /// Label baris. Selalu dirender dalam huruf kapital — itu suara panel
  /// instrumen ini, dan ia yang memisahkan label dari nilainya tanpa garis.
  final String label;

  final String value;

  /// Menggantikan gaya monospace baku, misalnya untuk nilai yang berupa kalimat
  /// dan bukan angka.
  final TextStyle? valueStyle;

  /// Menggantikan seluruh sisi nilai bila nilainya bukan sekadar teks —
  /// misalnya sebuah lencana status. [value] tetap wajib diisi sebagai teks
  /// cadangan baris ini.
  final Widget? trailing;

  /// Selisih terhadap pembanding, misalnya "+11 mnt". Setiap angka besar di
  /// aplikasi ini membawa pembandingnya.
  final String? delta;

  final AppBadgeTone deltaTone;

  final double labelWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final Widget labelWidget = Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(color: palette.textMuted),
    );

    final Widget valueWidget =
        trailing ??
        Text(
          value,
          style:
              valueStyle ??
              AppTypography.mono(color: theme.colorScheme.onSurface),
        );

    final Widget valueWithDelta = delta == null
        ? valueWidget
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: valueWidget),
              const SizedBox(width: AppSpacing.sm),
              AppBadge(label: delta!, tone: deltaTone, dense: true),
            ],
          );

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double scaledLabel = MediaQuery.textScalerOf(context).scale(11);
          // Dua alasan menumpuk: hurufnya sudah terlalu besar untuk kolom
          // selebar ini, atau kolomnya sendiri tinggal separuh layar sempit.
          final bool stacked =
              scaledLabel > 14 ||
              (constraints.hasBoundedWidth &&
                  constraints.maxWidth < labelWidth * 2.5);

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                labelWidget,
                const SizedBox(height: AppSpacing.tight),
                valueWithDelta,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                // Micro-label duduk sedikit lebih rendah supaya garis dasarnya
                // sejajar dengan nilai yang lebih besar di sebelahnya.
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: labelWidget,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: valueWithDelta),
            ],
          );
        },
      ),
    );
  }
}
