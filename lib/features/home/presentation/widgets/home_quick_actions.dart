import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/layout/app_breakpoints.dart';
import 'package:flutter/material.dart';

/// Satu pintu masuk cepat.
class HomeQuickAction {
  const HomeQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.accent = false,
    this.badge,
  });

  final IconData icon;

  /// Satu atau dua kata. Label tiga kata pada skala teks 1,5 di kolom selebar
  /// 70dp menjadi tiga baris, dan tiga baris membuat petaknya lebih tinggi
  /// daripada ikonnya.
  final String label;

  /// Sublabel pendukung (misal: "Pulang", "Formulir", "Log Bulan").
  final String? subtitle;

  final VoidCallback onTap;

  /// Sorotan hijau tipis untuk SATU petak, dan hanya ketika jalurnya benar-benar
  /// terbuka.
  final bool accent;

  /// Lencana teks/angka opsional (misal: "2").
  final String? badge;
}

/// Akses cepat, sebagai petak ikon — bukan sebagai deretan kartu.
///
/// Versi sebelumnya membungkus setiap aksi di dalam sebuah [AppCard] penuh:
/// garis 1px, radius, padding 16/20, dan kotak ikon 44px di dalamnya. Tiga
/// aksi memakan tinggi yang sama dengan panel absensi di atasnya, dan mata
/// membaca halaman itu sebagai empat hal yang sama pentingnya. Sebuah pintu
/// masuk bukan sebuah panel data; ia tidak butuh bidangnya sendiri.
///
/// Jadi petaknya kehilangan kartunya dan menyisakan yang benar-benar dipakai
/// orang untuk mengenalinya: kotak ikon, dan satu kata di bawahnya. Yang
/// dihemat bukan piksel melainkan bobot visual — dan bobot itu dikembalikan ke
/// panel yang memang harus dibaca lebih dulu.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key, required this.actions});

  final List<HomeQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final int columns = AppLayout.of(context).quickActionColumns.clamp(1, 6);
    final List<Widget> rows = <Widget>[];

    for (int start = 0; start < actions.length; start += columns) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: AppSpacing.md));
      }

      final List<Widget> cells = <Widget>[];

      for (int column = 0; column < columns; column++) {
        if (column > 0) {
          cells.add(const SizedBox(width: AppSpacing.sm));
        }

        final int index = start + column;

        cells.add(
          Expanded(
            child: index < actions.length
                ? _QuickActionTile(action: actions[index])
                // Petak kosong tetap mengambil kolomnya, supaya lebar petak
                // tidak berubah dari baris ke baris.
                : const SizedBox.shrink(),
          ),
        );
      }

      // `IntrinsicHeight` dan bukan `childAspectRatio`: rasio tetap memaksa
      // tinggi petak mengikuti LEBAR layar, dan pada 320dp dengan skala teks
      // 1,5 label dua baris meluap keluar petaknya. Di sini tinggi baris
      // ditentukan petak paling tinggi, jadi label yang panjang menumbuhkan
      // barisnya alih-alih terpotong.
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cells,
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.action});

  final HomeQuickAction action;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;

    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final bool isDark = theme.brightness == Brightness.dark;
    final HomeQuickAction action = widget.action;

    final Color background = action.accent
        ? palette.brandSubtle
        : palette.surfaceSubtle;
    final Color foreground = action.accent
        ? theme.colorScheme.primary
        : (action.badge != null
            ? palette.warning.foreground
            : theme.colorScheme.onSurface);
    final Color edge = action.accent
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.22)
        : palette.borderSubtle;

    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(14),
          // Sumbernya `onHighlightChanged`, bukan `GestureDetector`: awal gulir
          // membatalkan penekanan alih-alih melawan `ListView` di atasnya.
          onHighlightChanged: _setPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: action.accent
                  ? palette.brandSubtle
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: action.accent
                    ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.45 : 0.35)
                    : palette.borderSubtle,
                width: 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      AnimatedScale(
                        scale: _pressed ? 0.94 : 1,
                        duration: AppDurations.fast,
                        curve: AppMotion.standard,
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          curve: AppMotion.standard,
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _pressed
                                ? (action.accent ? palette.brandSubtle : palette.surfaceSubtle)
                                : background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _pressed
                                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                  : edge,
                              width: _pressed ? 1.5 : 1.0,
                            ),
                          ),
                          child: Icon(
                            action.icon,
                            size: 22,
                            color: foreground,
                          ),
                        ),
                      ),
                      if (action.badge != null)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              action.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      action.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: action.accent
                            ? (isDark
                                ? theme.colorScheme.primary
                                : const Color(0xFF047857))
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (action.subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        action.subtitle!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: action.accent
                              ? theme.colorScheme.primary
                              : (action.badge != null
                                  ? palette.warning.foreground
                                  : palette.textMuted),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
