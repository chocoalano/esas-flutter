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
    this.accent = false,
  });

  final IconData icon;

  /// Satu atau dua kata. Label tiga kata pada skala teks 1,5 di kolom selebar
  /// 70dp menjadi tiga baris, dan tiga baris membuat petaknya lebih tinggi
  /// daripada ikonnya.
  final String label;

  final VoidCallback onTap;

  /// Sorotan hijau tipis untuk SATU petak, dan hanya ketika jalurnya benar-benar
  /// terbuka.
  ///
  /// Petak ini pernah punya rupa "ditekankan" berisian hijau penuh, dan itu
  /// dilepas karena aksen tunggal produk dibelanjakan pada elemen paling tidak
  /// penting. Yang kembali sekarang jauh lebih pelan — isian `brandSubtle` dan
  /// ikon hijau pada satu petak dari empat — dan ia mati sendiri ketika absensi
  /// tidak tersedia, sehingga tidak pernah menjanjikan pintu yang terkunci.
  final bool accent;
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
    final HomeQuickAction action = widget.action;

    // Netral, dan itu seluruh maksudnya. Petak ini pernah punya dua rupa —
    // hijau penuh untuk aksi utama, hijau tipis untuk sisanya — dan tangkapan
    // layar membuktikan hasilnya: satu-satunya momen berwarna di seluruh
    // dasbor adalah petak "Absen", yaitu aksen tunggal produk ini dibelanjakan
    // pada elemen paling tidak penting, sementara jalur yang sama sudah
    // ditawarkan sebagai tombol selebar penuh di dalam panel protagonis.
    //
    // Melepas `emphasized` saja tidak cukup: empat kotak ikon 52dp berisian
    // `brandSubtle` berjumlah ~10.800 dp² nada brand di dalam pita Tingkat 2,
    // hampir empat kali luas nada yang dipegang panel protagonis sendiri. Pita
    // penopang yang lebih berwarna daripada protagonisnya membatalkan seluruh
    // hierarki, jadi petaknya sekarang memakai permukaan yang sama dengan ubin
    // sisa cuti di sebelahnya: satu langkah permukaan di atas pita, garis
    // rambut, tinta biasa. Yang membuat Tingkat 1 terbaca lebih penting bukan
    // karena ia lebih berwarna, melainkan karena di sini tidak ada warna.
    final Color background = action.accent
        ? palette.brandSubtle
        : theme.colorScheme.surface;
    final Color foreground = action.accent
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    final Color edge = action.accent
        ? theme.colorScheme.primary.withValues(alpha: 0.22)
        : palette.borderSubtle;

    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: AppRadii.xlAll,
          // Sumbernya `onHighlightChanged`, bukan `GestureDetector`: awal gulir
          // membatalkan penekanan alih-alih melawan `ListView` di atasnya.
          onHighlightChanged: _setPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedScale(
                  scale: _pressed ? 0.94 : 1,
                  duration: AppDurations.fast,
                  curve: AppMotion.standard,
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: AppRadii.xlAll,
                      border: Border.all(color: edge),
                    ),
                    child: Icon(
                      action.icon,
                      size: AppIconSizes.xxl,
                      color: foreground,
                    ),
                  ),
                ),
                // 6, bukan 8. Kotak ikon dan labelnya adalah SATU benda, dan
                // jarak yang sama dengan jarak antar petak membuat keduanya
                // terbaca sebagai dua benda yang berdekatan.
                const SizedBox(height: AppSpacing.tight),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
