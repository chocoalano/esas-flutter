import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// Avatar karyawan, dengan inisial sebagai cadangan.
///
/// Bentuknya persegi bersudut tumpul, bukan lingkaran: sudut yang sama dengan
/// kartu di sekitarnya membuat avatar menyatu ke dalam tata letak alih-alih
/// mengambang di atasnya. Latarnya isian brand yang tipis dengan garis 1px,
/// mengikuti pola permukaan yang sama seperti seluruh aplikasi.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.userName,
    this.imageUrl,
    this.size = 40,
    this.borderRadius,
    this.onTap,
    this.badge,
  });

  final String userName;

  /// URL absolut. Selesaikan path tersimpan dengan `assetUrl()` lebih dulu.
  final String? imageUrl;

  final double size;
  final BorderRadius? borderRadius;

  /// Membuat avatar bisa diketuk — misalnya menuju halaman profil. Riak
  /// digambar di atas fotonya, bukan di belakang kotak buram.
  final VoidCallback? onTap;

  /// Penanda kecil di sudut kanan bawah, di luar area terpotong avatar.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(size / 3.2);

    // Foto karyawan datang dalam resolusi penuh dan didekode ke dalam kotak
    // 40px, berulang per baris di sheet detail absensi, pada perangkat Android
    // kelas bawah. Batas dekode disetel ke ukuran tampil dikali kepadatan
    // piksel layar: setajam yang bisa dilihat mata, tidak lebih.
    final int cacheEdge = (size * MediaQuery.devicePixelRatioOf(context))
        .round();

    Widget box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.brandSubtle,
        borderRadius: radius,
        border: Border.all(color: palette.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              _initials(userName),
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (hasImage)
            Image.network(
              url,
              fit: BoxFit.cover,
              // Width only (UI-03): both set means ResizeImagePolicy.exact,
              // which squashed a portrait into a square before `cover` saw it.
              // Employee photos are portraits; their width is the short side.
              cacheWidth: cacheEdge,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
              // Fade the photo in from transparent once its first frame is
              // ready. `frame == null` means still downloading, so opacity 0.0
              // leaves the initials visible beneath. When the frame arrives the
              // AnimatedOpacity interpolates to 1.0.
              frameBuilder: (context, child, frame, wasSynchronous) {
                if (wasSynchronous) return child;
                return AnimatedOpacity(
                  opacity: frame != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeIn,
                  child: child,
                );
              },
            ),
          if (onTap != null)
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, borderRadius: radius),
              ),
            ),
        ],
      ),
    );

    if (badge != null) {
      box = Stack(alignment: Alignment.bottomRight, children: [box, badge!]);
    }

    // Satu simpul, satu nama. Tanpa ini teknologi bantu membacakan inisialnya
    // ("AG") alih-alih orang yang diwakilinya.
    return Semantics(
      label: userName,
      button: onTap != null,
      image: hasImage,
      container: true,
      onTap: onTap,
      child: ExcludeSemantics(child: box),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((e) => e[0]).join().toUpperCase();
  }
}
