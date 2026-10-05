import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_segmented_progress.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:esas/features/permit/presentation/widgets/permit_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Satu pengajuan di dalam daftar riwayat.
///
/// Kartu ini dulu setinggi 165dp untuk membawa enam baris, dan tiga di
/// antaranya tidak pernah berubah dari baris ke baris: kolom ikon meta yang
/// mengulang bentuk yang sama, kalimat "2 dari 3 persetujuan masuk", dan nama
/// pemiliknya sendiri — daftar ini hanya berisi pengajuan milik orang yang
/// sedang membacanya, jadi namanya adalah teks yang identik di setiap kartu
/// selamanya.
///
/// Sekarang sekitar 104dp: jenis izin memimpin, status menjadi lencana di
/// kanan yang bisa dipindai satu kolom ke bawah, satu baris meta membawa
/// periode dan durasi sekaligus, dan kalimat persetujuan menjadi bar bersegmen
/// dengan angka "2/3" — bentuk yang terbaca sebelum kalimatnya sempat dibaca.
///
/// Nomor pengajuan tetap monospace dan tetap ada: orang membacakannya ke HR
/// lewat telepon, dan itu satu-satunya hal di kartu ini yang dieja huruf per
/// huruf.
class PermitListItem extends StatelessWidget {
  const PermitListItem({super.key, required this.permit});

  final Permit permit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final PermitStatus status = resolvePermitStatus(permit);
    final progress = permitApprovalProgress(permit);

    return AppCard(
      onTap: () => Get.toNamed(
        PermitRoutes.show,
        arguments: {'permit': permit, 'id': permit.id},
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                        permit.permitType?.type ?? 'Perizinan',
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppBadge(
                      label: status.label,
                      tone: status.tone,
                      icon: status.icon,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.tight),

                // Periode dan durasi pada satu baris. Keduanya menjawab
                // pertanyaan yang sama — kapan dan berapa lama — jadi memisahkan
                // keduanya ke dua baris berikon hanya menambah tinggi.
                Text(
                  _metaLine(permit),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.snug),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        permit.permitNumbers,
                        style: AppTypography.dataSmall(
                          color: palette.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (progress.total > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AppSegmentedProgress(
                        total: progress.total,
                        filled: progress.approved,
                        tone: status.colors(palette),
                        semanticsLabel:
                            '${progress.approved} dari ${progress.total} '
                            'persetujuan masuk',
                      ),
                    ],
                  ],
                ),
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
    );
  }

  /// `2 – 4 Sep 2026 · 3 hari`.
  static String _metaLine(Permit permit) {
    return '${_dateRange(permit)} · ${permit.durationInDays} hari';
  }

  /// Rentang tanggal sebagai satu frasa. Tanggal yang sama tidak ditulis dua
  /// kali — izin satu hari berbunyi "12 Mar 2026", bukan
  /// "12 Mar 2026 – 12 Mar 2026" — dan bulan yang sama hanya ditulis sekali.
  static String _dateRange(Permit permit) {
    final DateTime? start = permit.startDate;
    final DateTime? end = permit.endDate;

    if (start == null && end == null) return 'Tanggal belum ditentukan';

    final DateFormat full = DateFormat('d MMM yyyy', 'id');

    if (start == null || end == null) {
      return full.format((start ?? end)!);
    }

    if (start == end) return full.format(start);

    if (start.year == end.year && start.month == end.month) {
      return '${DateFormat('d', 'id').format(start)} – ${full.format(end)}';
    }

    return '${full.format(start)} – ${full.format(end)}';
  }
}
