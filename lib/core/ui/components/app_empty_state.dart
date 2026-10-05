import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Keadaan kosong yang menjelaskan, bukan sekadar melapor.
///
/// Versi sebelumnya menampilkan satu baris teks abu-abu di tengah layar
/// ("Tidak ada notifikasi."). Sebuah keadaan kosong yang baik menyebutkan apa
/// yang seharusnya ada di sana dan menawarkan langkah berikutnya, karena layar
/// kosong sering kali adalah layar pertama yang dilihat karyawan baru.
///
/// Langkah utamanya sengaja digambar sebagai `OutlinedButton`. Daftar yang
/// kosong adalah keadaan yang wajar, bukan kegagalan, jadi bobot ajakannya satu
/// tingkat lebih pelan daripada tombol coba lagi di `AppErrorState` — dan
/// perbedaan bobot itulah yang membedakan kedua keadaan dari kejauhan, sebelum
/// satu huruf pun terbaca.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Varian ringkas untuk kartu, bukan untuk satu halaman penuh.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final Widget content = Padding(
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
              color: palette.surfaceSubtle,
              borderRadius: AppRadii.xlAll,
              border: Border.all(color: palette.borderSubtle),
            ),
            child: Icon(
              icon,
              size: compact ? AppIconSizes.xl : AppIconSizes.xxl,
              color: palette.textMuted,
            ),
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.tight),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );

    // Sebuah keadaan kosong yang dipusatkan hanya benar selama isinya memang
    // muat. Pada ponsel dalam lanskap — 390dp tinggi, dikurangi bilah judul —
    // tingginya tersisa sekitar 238dp, dan pada skala teks 1,3 ikon 56dp
    // bersama judul, kalimat, dan tombolnya sudah melewatinya. Yang terpotong
    // justru bagian terbawah, yaitu tombol yang menawarkan langkah berikutnya:
    // keadaan kosong kehilangan satu-satunya hal yang membuatnya berguna.
    //
    // Karena itu isinya boleh digulir ketika tingginya terbatas, dan tetap
    // terpusat selama masih muat — `minHeight` sebesar viewport-nya yang
    // menjaga keduanya sekaligus. Ketika tingginya TIDAK terbatas, widget ini
    // sedang berada di dalam sesuatu yang sudah menggulir; membungkusnya lagi
    // akan membuat dua scrollable bersarang pada sumbu yang sama, jadi di sana
    // ia dibiarkan apa adanya.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedHeight) return Center(child: content);

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
