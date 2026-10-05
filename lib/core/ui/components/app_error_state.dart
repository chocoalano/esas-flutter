import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Keadaan gagal muat, sebagai keadaan tersendiri di samping `AppEmptyState`.
///
/// Selama ini daftar-daftar di aplikasi ini hanya punya dua cabang: memuat dan
/// kosong. Akibatnya karyawan yang koneksinya putus diberi tahu bahwa ia tidak
/// pernah mengajukan cuti — di sebuah HRMS itu bukan kekurangan poles, itu
/// kalimat keliru yang bersinggungan langsung dengan payroll.
///
/// Karena itu urutan cabangnya juga bagian dari komponen ini: periksa error
/// LEBIH DULU, baru kosong. Halaman pertama yang gagal selalu menghasilkan
/// daftar kosong juga, jadi cabang kosong yang diperiksa duluan akan menelan
/// setiap kegagalan tanpa sisa.
///
/// Bedanya dengan keadaan kosong sengaja dibuat terbaca dari kejauhan: chip
/// ikonnya bernada `danger`, dan langkah utamanya adalah `FilledButton` — satu
/// tingkat lebih tegas daripada `OutlinedButton` di sana, karena mencoba lagi
/// memang tindakan yang diharapkan, bukan sekadar tawaran.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Gagal memuat',
    required this.message,
    this.icon = Icons.cloud_off_rounded,
    this.actionLabel = 'Coba lagi',
    this.onRetry,
    this.compact = false,
  });

  final String title;

  /// Kalimat dari server, apa adanya. Pesan yang sebenarnya — "koneksi
  /// terputus", "sesi berakhir" — memberi tahu apakah menunggu ada gunanya;
  /// satu kalimat generik tidak pernah bisa.
  final String message;

  final IconData icon;
  final String actionLabel;
  final VoidCallback? onRetry;

  /// Varian ringkas untuk di dalam kartu, bukan untuk satu halaman penuh.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final AppTone tone = palette.danger;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: compact ? AppSpacing.xxl : AppSpacing.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 44 : 56,
              height: compact ? 44 : 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.background,
                borderRadius: AppRadii.xlAll,
                border: Border.all(color: tone.border),
              ),
              child: Icon(
                icon,
                size: compact ? AppIconSizes.xl : AppIconSizes.xxl,
                color: tone.foreground,
              ),
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.tight),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onRetry, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
