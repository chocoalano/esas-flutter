import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/features/permit/data/models/leave_type.dart';
import 'package:esas/features/permit/data/models/permit_variant.dart';
import 'package:flutter/material.dart';

/// Satu jenis perizinan, sebagai baris di dalam panel.
///
/// Sebelumnya ini adalah kartu persegi di dalam grid dua kolom: ikon bulat
/// besar di tengah, nama di bawahnya, status bayar di kaki. Bentuk itu memaksa
/// nama yang panjang ("Cuti melahirkan anak pertama") terpotong menjadi dua
/// baris dengan elipsis, padahal nama itulah satu-satunya hal yang dibaca orang
/// saat memilih.
///
/// Sebagai baris, nama mendapat seluruh lebar layar, dan atribut yang benar
/// benar menentukan pilihan — perlu lampiran atau tidak, varian mana yang akan
/// membuka field tambahan — dibawa lencana alih-alih baru ketahuan di dalam
/// formulir.
///
/// Sepuluh baris jenis izin dulu merender sekitar dua puluh lima lencana
/// berwarna pada layar pertama fitur ini, dua di antaranya memakai warna yang
/// sistem ini cadangkan untuk status. Yang tersisa sekarang paling banyak dua
/// per baris: satu varian, satu lampiran.
class LeaveTypeRow extends StatelessWidget {
  const LeaveTypeRow({super.key, required this.item, required this.onTap});

  final LeaveType item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            AppIconBox(icon: iconForLeaveType(item.type), size: 38),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.type,
                          style: theme.textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Varian yang membuka field tambahan disebut dengan
                      // namanya, di kolom kanan yang sama dengan lencana
                      // lampiran, sehingga kedua atribut yang menentukan bentuk
                      // formulir berikutnya terbaca sebagai satu kolom.
                      //
                      // Lencana kode mentah dibuang: `ANNUAL` dan `SICK` adalah
                      // nama perusahaan untuk jenis ini, bukan kalimat untuk
                      // staf pabrik yang sedang memilih.
                      if (item.variant != PermitVariant.general) ...[
                        const SizedBox(width: AppSpacing.sm),
                        AppBadge(label: item.variant.label, dense: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  // Status upah turun ke baris keterangan sebagai teks redup.
                  // Ia atribut, bukan status, dan dua nada warna yang dipakai
                  // sistem ini untuk status tidak boleh dibelanjakan padanya.
                  Text(
                    _subtitle(item),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.withFile) ...[
                    const SizedBox(height: AppSpacing.tight),
                    // Syarat yang paling mahal bila baru ketahuan di dalam
                    // formulir: orang sudah mengisi sepuluh field sebelum tahu
                    // ia perlu memotret surat dokter.
                    const AppBadge(
                      label: 'Perlu lampiran',
                      tone: AppBadgeTone.info,
                      icon: Icons.attach_file_rounded,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              size: AppIconSizes.lg,
              color: palette.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  /// Keterangan jenis izin, dengan status upah dilipat ke dalamnya.
  ///
  /// Kata upahnya hanya muncul bila server benar-benar mengatakannya. Kontrak
  /// API yang baru tidak punya field itu, dan menebaknya berarti memberi tahu
  /// karyawan bahwa izinnya dibayar padahal belum tentu.
  static String _subtitle(LeaveType item) {
    final String description = (item.description ?? '').trim();
    final String? wage = item.isPayed == null
        ? null
        : (item.isPayed! ? 'Dibayar' : 'Tanpa upah');

    if (wage == null) {
      return description.isEmpty ? 'Tanpa keterangan tambahan.' : description;
    }
    if (description.isEmpty) return wage;
    return '$wage · $description';
  }
}

/// Ikon untuk sebuah jenis cuti.
///
/// Dipindahkan keluar dari `PermitView` supaya baris dan layar rincian memakai
/// ikon yang sama untuk jenis yang sama — jenis izin yang berganti ikon antar
/// layar membuat orang ragu apakah ia melihat hal yang sama.
IconData iconForLeaveType(String type) {
  final String t = type.toLowerCase();
  if (t.contains('cuti') && !t.contains('sakit')) {
    return Icons.beach_access_outlined;
  }
  if (t.contains('nikah') || t.contains('menikahkan')) {
    return Icons.favorite_outline;
  }
  if (t.contains('khitan') || t.contains('baptis')) {
    return Icons.child_care_outlined;
  }
  if (t.contains('melahirkan')) return Icons.pregnant_woman_outlined;
  if (t.contains('sakit')) return Icons.medical_services_outlined;
  if (t.contains('wisuda')) return Icons.school_outlined;
  if (t.contains('ibadah')) return Icons.self_improvement_outlined;
  if (t.contains('duka') || t.contains('meninggal')) return Icons.spa_outlined;
  if (t.contains('dinas') || t.contains('tugas')) {
    return Icons.flight_takeoff_outlined;
  }
  if (t.contains('lain')) return Icons.more_horiz_rounded;
  return Icons.event_outlined;
}

/// Pembungkus panel untuk sekumpulan [LeaveTypeRow].
class LeaveTypePanel extends StatelessWidget {
  const LeaveTypePanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).palette;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.borderSubtle),
            children[i],
          ],
        ],
      ),
    );
  }
}
