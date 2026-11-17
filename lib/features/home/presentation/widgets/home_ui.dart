import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Bahasa visual Beranda: kartu lunak berbingkai garis, pil status, kotak ikon
/// berwarna lembut, dan judul bagian yang tebal.
///
/// Empat potong ini dipakai oleh SETIAP bagian Beranda. Selama tiap widget
/// menulis sendiri `BoxDecoration`-nya, radius, tebal garis, dan nada pil
/// akan bergeser satu per satu — persis cara sebuah halaman kehilangan
/// konsistensinya.
///
/// Semua warna datang dari tema ([ThemeData.colorScheme] dan [AppPalette]),
/// tidak pernah dari heksadesimal: hijau brand di mode terang adalah
/// `colorScheme.primary` (5,35:1 terhadap putih), bukan hijau yang lebih terang
/// yang gagal AA sebagai latar teks putih. Tidak ada gradien, bayangan, atau
/// blur — kedalaman hanya dari garis 1px dan selisih permukaan; aturan itu
/// ditegakkan `test/core/ui/no_gradient_test.dart`.
///
/// Tingkat radius yang dipakai Beranda:
/// * [AppRadii.xxxl] (20) — panel hero.
/// * [AppRadii.xxl] (16) — kartu biasa.
/// * [AppRadii.xl] (12) — petak aksi dan kotak ikon.
/// * [AppRadii.pill] — pil status.
class HomeSurface extends StatelessWidget {
  const HomeSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadii.xxlAll,
    this.highlight = false,
    this.onTap,
    this.semanticsLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;

  /// Isian hijau tipis dan garis hijau, untuk SATU permukaan yang sedang
  /// ditonjolkan (misalnya petak aksi yang memang bisa diketuk sekarang).
  final bool highlight;

  /// Bila diisi, seluruh permukaan menjadi target ketuk dengan riak.
  final VoidCallback? onTap;

  /// Label pembaca layar untuk permukaan yang bisa diketuk. Tanpa ini, isi
  /// teks di dalamnya dibacakan apa adanya.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    final Color fill = highlight ? palette.brandSubtle : theme.colorScheme.surface;
    final Color line = highlight
        ? theme.colorScheme.primary.withValues(alpha: 0.35)
        : palette.borderSubtle;

    Widget surface = Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );

    if (onTap != null && semanticsLabel != null) {
      surface = Semantics(
        button: true,
        label: semanticsLabel,
        excludeSemantics: true,
        child: surface,
      );
    }

    return surface;
  }
}

/// Pil status kecil: titik atau ikon opsional, lalu satu label pendek.
///
/// Nadanya diambil dari [AppPalette], jadi isian, garis, dan hurufnya berpindah
/// bersama tema dan setiap pasangan sudah dirancang lolos AA. `tone: null`
/// berarti netral.
class HomePill extends StatelessWidget {
  const HomePill({
    super.key,
    required this.label,
    this.tone,
    this.icon,
    this.showDot = false,
    this.mono = false,
    this.compact = false,
    this.solid = false,
  });

  final String label;
  final AppTone? tone;
  final IconData? icon;

  /// Titik 6px di depan label (keadaan "hidup", misalnya sinkron).
  final bool showDot;

  /// Label berupa angka atau jam: pakai font tabular supaya tidak bergoyang.
  final bool mono;

  /// Padding dan ukuran lebih rapat, untuk pil di dalam baris data.
  final bool compact;

  /// Isian penuh warna nada (huruf putih/gelap tema) alih-alih isian lembut.
  /// Dipakai untuk lencana hitungan, bukan untuk status.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;
    final AppTone t = tone ?? palette.neutral;

    final Color fill = solid ? t.foreground : t.background;
    final Color line = solid ? t.foreground : t.border;
    final Color ink = solid ? theme.colorScheme.surface : t.foreground;

    final TextStyle base = mono
        ? AppTypography.mono(
            color: ink,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          )
        : (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
            color: ink,
            fontSize: compact ? 11 : 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.tight : AppSpacing.snug,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showDot) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs + 1),
          ] else if (icon != null) ...<Widget>[
            Icon(icon, size: AppIconSizes.sm, color: ink),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: base,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotak ikon berwarna lembut: pengenal sebuah petak atau baris.
///
/// Ukurannya ditetapkan oleh pemanggil; radiusnya mengikuti sepertiga sisi
/// supaya kotak 36 dan kotak 48 sama-sama terbaca "satu keluarga".
class HomeIconBox extends StatelessWidget {
  const HomeIconBox({
    super.key,
    required this.icon,
    this.tone,
    this.size = 40,
    this.iconSize = AppIconSizes.xl,
    this.solid = false,
  });

  final IconData icon;

  /// `null` = netral (isian lembut abu, ikon tinta teks).
  final AppTone? tone;
  final double size;
  final double iconSize;

  /// Isian penuh warna brand dengan ikon `onPrimary` — penekanan untuk SATU
  /// petak yang jalurnya sedang terbuka.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;
    final AppTone t = tone ?? palette.neutral;

    final Color fill = solid ? theme.colorScheme.primary : t.background;
    final Color line = solid ? theme.colorScheme.primary : t.border;
    final Color ink = solid
        ? theme.colorScheme.onPrimary
        : (tone == null ? theme.colorScheme.onSurface : t.foreground);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size / 3),
        border: Border.all(color: line),
      ),
      child: Icon(icon, size: iconSize, color: ink),
    );
  }
}

/// Judul sebuah bagian Beranda: tebal, dengan satu kalimat penjelas redup dan
/// tautan aksi hijau di sisi kanan.
///
/// Menggantikan `AppSectionHeader(naturalCase: true)` di layar ini saja.
/// Header bersama sengaja dibiarkan apa adanya — ia dipakai layar lain yang
/// bahasanya micro-label, dan bendera baru di sana lebih mahal daripada satu
/// widget di sini.
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
  });

  final String title;
  final String? subtitle;

  /// Teks tautan di kanan. Aksi hanya digambar bila KEDUANYA terisi: sebuah
  /// tautan tanpa tujuan adalah tombol yang hanya bisa gagal.
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;
    final bool hasAction = actionLabel != null && onAction != null;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasAction) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onAction,
              // Tema memberi tombol teks target 36dp; di sini ia adalah
              // afordans navigasi tersendiri, jadi dinaikkan ke 48dp.
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                foregroundColor: theme.colorScheme.primary,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    actionLabel!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: AppIconSizes.lg,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
