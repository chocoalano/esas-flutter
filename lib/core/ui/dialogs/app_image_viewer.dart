import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Memperbesar sebuah gambar (foto absensi, lampiran pengajuan) layar penuh.
///
/// Dua layar sebelumnya membuka `Dialog` polos berisi `InteractiveViewer`, dan
/// keduanya sama-sama kekurangan tiga hal yang membuat sebuah penampil gambar
/// bisa dipakai:
///
/// * **Tombol tutup.** `InteractiveViewer` menelan gestur ketuk, jadi satu-
///   satunya cara menutup adalah mengetuk barrier di luar gambar — dan pada
///   gambar yang memenuhi dialog, barrier itu tidak ada. Sekarang ada tombol
///   tutup 48dp di pojok.
/// * **Keadaan memuat.** Foto dari jaringan digambar kosong sampai selesai;
///   sekarang ada indikator dengan kemajuan bila ukurannya diketahui.
/// * **Keadaan gagal.** Gambar yang tidak terbaca menggambar ikon rusak
///   bawaan Flutter di atas latar gelap. Sekarang ada kalimat yang
///   menyebutnya.
///
/// Warna datang dari peran `overlay*` palet — kerudung yang sama dengan lapisan
/// di atas kamera — supaya tidak ada ejaan keempat dari "hitam transparan".
Future<void> showAppImageViewer(
  BuildContext context, {
  required ImageProvider image,
  String? title,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _ImageViewer(image: image, title: title),
  );
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.image, this.title});

  final ImageProvider image;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    return Dialog.fullscreen(
      backgroundColor: palette.overlayScrim,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image(
                image: image,
                fit: BoxFit.contain,
                semanticLabel: title,
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? progress,
                    ) {
                      if (progress == null) return child;

                      final int? total = progress.expectedTotalBytes;

                      return Center(
                        child: CircularProgressIndicator(
                          value: total == null
                              ? null
                              : progress.cumulativeBytesLoaded / total,
                          color: palette.onOverlay,
                          semanticsLabel: 'Memuat gambar',
                        ),
                      );
                    },
                errorBuilder: (BuildContext context, Object _, StackTrace? _) =>
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.image_not_supported_outlined,
                            size: AppIconSizes.xxl * 2,
                            color: palette.onOverlayMuted,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Gambar tidak dapat dimuat.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.onOverlay,
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.sm,
                              top: AppSpacing.md,
                            ),
                            child: Text(
                              title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: palette.onOverlay,
                              ),
                            ),
                          ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: palette.onOverlay,
                      backgroundColor: palette.overlayScrim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
