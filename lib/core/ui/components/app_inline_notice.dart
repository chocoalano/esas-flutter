import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Seberapa keras sebuah pemberitahuan sebaris berbicara.
enum AppNoticeTone { info, warning, danger, neutral }

/// Kabar buruk seukuran kalimatnya.
///
/// [AppErrorState] dan [AppEmptyState] adalah keadaan sebuah HALAMAN: keduanya
/// memusatkan diri, memasang chip ikon 44–56px, dan memberi jarak `huge` di
/// atas dan di bawah. Itu benar ketika yang gagal adalah seluruh isi layar.
///
/// Itu menjadi salah ketika yang gagal hanya satu panel. Di Beranda, satu
/// permintaan absensi yang gagal menggambar kartu setinggi ~200px berisi
/// "Gagal memuat", satu kalimat teknis, dan sebuah tombol — mendorong akses
/// cepat, jadwal, dan pengumuman ke bawah lipatan, padahal ketiganya berhasil
/// dimuat dan tetap bisa dipakai. Kegagalan satu panel tidak boleh
/// membelanjakan layar milik panel yang lain.
///
/// Jadi yang ini setinggi kalimatnya. Ikonnya seukuran huruf, tidak ada chip,
/// tidak ada pemusatan, dan aksinya adalah tombol teks di baris tersendiri —
/// baris kedua, bukan di samping teks, karena label bahasa Indonesia pada skala
/// teks 1,5 di layar 320dp tidak pernah muat berdampingan dengan sebuah
/// kalimat.
class AppInlineNotice extends StatelessWidget {
  const AppInlineNotice({
    super.key,
    required this.message,
    this.tone = AppNoticeTone.danger,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  /// Satu kalimat, dalam bahasa yang dipakai orang. Bukan kode status, bukan
  /// nama pengecualian.
  final String message;

  final AppNoticeTone tone;

  /// Bila dikosongkan, dipilih dari [tone] — sehingga keadaan tetap terbaca
  /// lewat BENTUK, bukan hanya lewat warna.
  final IconData? icon;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Aksi kedua, dipakai hanya ketika benar-benar ada dua jalan keluar yang
  /// berbeda — misalnya "Coba lagi" di samping "Masuk kembali". Sebuah
  /// pemberitahuan dengan dua tombol yang mengerjakan hal yang sama adalah
  /// pemberitahuan yang belum diputuskan.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  AppTone _colors(AppPalette palette) => switch (tone) {
    AppNoticeTone.info => palette.info,
    AppNoticeTone.warning => palette.warning,
    AppNoticeTone.danger => palette.danger,
    AppNoticeTone.neutral => palette.neutral,
  };

  IconData get _icon =>
      icon ??
      switch (tone) {
        AppNoticeTone.info => Icons.info_outline_rounded,
        AppNoticeTone.warning => Icons.warning_amber_rounded,
        AppNoticeTone.danger => Icons.cloud_off_rounded,
        AppNoticeTone.neutral => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppTone colors = _colors(theme.palette);

    final bool hasPrimary = actionLabel != null && onAction != null;
    final bool hasSecondary =
        secondaryActionLabel != null && onSecondaryAction != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.snug,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                // Menurunkan ikon setengah baris supaya ia sejajar dengan
                // huruf pertama, bukan dengan tepi atas kotak teks.
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Icon(
                  _icon,
                  size: AppIconSizes.md,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ),
            ],
          ),
          if (hasPrimary || hasSecondary) ...[
            const SizedBox(height: AppSpacing.xs),
            // `Wrap` dan bukan `Row`: dua label aksi pada skala teks 1,5 di
            // layar 320dp meluap sebagai baris dan tidak meluap sebagai dua
            // baris.
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                if (hasPrimary)
                  _NoticeAction(
                    label: actionLabel!,
                    onPressed: onAction!,
                    color: colors.foreground,
                  ),
                if (hasSecondary)
                  _NoticeAction(
                    label: secondaryActionLabel!,
                    onPressed: onSecondaryAction!,
                    color: colors.foreground,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tombol teks di dalam pemberitahuan.
///
/// Target sentuhnya dijaga 44dp lewat `minimumSize`, sementara padding
/// visualnya dirapatkan — sebuah pemberitahuan sebaris kehilangan seluruh
/// alasannya kalau tombolnya setinggi tombol halaman.
class _NoticeAction extends StatelessWidget {
  const _NoticeAction({
    required this.label,
    required this.onPressed,
    required this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: theme.textTheme.labelLarge,
      ),
      child: Text(label),
    );
  }
}
