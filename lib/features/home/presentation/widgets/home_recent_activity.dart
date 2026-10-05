import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:esas/features/permit/presentation/widgets/permit_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Beberapa pengajuan terakhir, sebagai baris — bukan sebagai kartu.
///
/// Bagian ini yang menutup pertanyaan terakhir sebuah dasbor karyawan: *apa
/// yang terjadi dengan hal yang saya kirim kemarin*. Beranda sebelumnya
/// berhenti pada kabar perusahaan, sehingga hasil dari tindakan orangnya
/// sendiri adalah satu-satunya hal yang harus dicari di tab lain.
///
/// Bentuknya baris dan bukan kartu dengan sengaja. Halaman ini sudah punya
/// kartu protagonis, kartu pengumuman, dan ubin metrik; ragam keempat berupa
/// kartu lagi akan membuat semuanya terbaca sama pentingnya. Tiga baris di
/// dalam satu permukaan bersama terbaca sebagai satu daftar, yang memang
/// isinya.
///
/// Statusnya datang dari [resolvePermitStatus] — kamus yang sama yang dipakai
/// layar Pengajuan dan layar rincian. Tidak ada pencocokan string di sini, dan
/// tidak boleh ada: sebuah pengajuan tidak boleh tampil "Diproses" di Beranda
/// dan "Ditolak" dua ketukan kemudian.
class HomeRecentActivity extends StatelessWidget {
  const HomeRecentActivity({
    super.key,
    required this.permits,
    required this.loading,
    required this.error,
  });

  final List<Permit> permits;
  final bool loading;

  /// Gagal dimuat. Bagian sekunder yang gagal menghilang — kegagalannya sudah
  /// tercatat di log oleh `HomeController._load`.
  final bool error;

  bool get hasContent => loading || !error;

  /// Apakah judul bagiannya layak membawa tautan "Semua".
  bool get isNavigable => !loading && !error && permits.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _ActivitySkeleton();
    if (error) return const SizedBox.shrink();
    if (permits.isEmpty) return const _EmptyActivity();

    final AppPalette palette = Theme.of(context).palette;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < permits.length; i++) ...<Widget>[
            if (i > 0)
              // Garis yang menjorok, bukan selebar kartu: ia memisahkan baris,
              // dan sebuah pemisah yang menyentuh kedua tepi memotong kartunya
              // menjadi tiga kartu kecil.
              Padding(
                padding: const EdgeInsets.only(left: 68),
                child: Divider(height: 1, color: palette.borderSubtle),
              ),
            _ActivityRow(permit: permits[i]),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.permit});

  final Permit permit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;
    final PermitStatus status = resolvePermitStatus(permit);

    final String title = permit.permitType?.type ?? 'Pengajuan';
    final String? date = _dateLabel(permit);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        // Rute dan argumen yang sama persis dengan baris di layar Pengajuan.
        // Sebuah tujuan kedua untuk benda yang sama adalah tempat kedua untuk
        // salah.
        onTap: () => Get.toNamed(
          PermitRoutes.show,
          arguments: <String, Object?>{'permit': permit, 'id': permit.id},
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              AppIconBox(
                // Satu ikon untuk semua jenis. Memetakan jenis izin ke ikon
                // menuntut kamus kanonis yang tidak dikirim server mana pun,
                // dan menebaknya dari nama jenis akan meleset pada instalasi
                // pertama yang menamai jenisnya sendiri.
                icon: Icons.description_outlined,
                size: 40,
                foreground: palette.textMuted,
                background: palette.surfaceSubtle,
                borderColor: palette.borderSubtle,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.tight),
                    // `Wrap` dan bukan `Row`: lencana status plus tanggal pada
                    // skala teks 1,5 di layar 320dp tidak muat berdampingan,
                    // dan yang benar adalah turun baris.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        AppBadge(
                          label: status.label,
                          tone: status.tone,
                          icon: status.icon,
                          dense: true,
                        ),
                        if (date != null)
                          Text(
                            date,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
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
        ),
      ),
    );
  }

  /// Tanggal mulainya izin, atau tanggal pengajuannya bila yang pertama tidak
  /// ada. Keduanya digambar pada jam workspace lewat [DateFormatter].
  static String? _dateLabel(Permit permit) {
    final DateTime? start = permit.startDate;

    if (start != null) return DateFormatter.timestamp(start, 'd MMM yyyy');

    final String? created = permit.createdAt;

    if (created == null) return null;

    final DateTime? parsed = DateTime.tryParse(created);

    return parsed == null
        ? null
        : DateFormatter.timestamp(parsed, 'd MMM yyyy');
  }
}

/// Berhasil dimuat, dan orangnya memang belum pernah mengajukan apa pun.
///
/// Bentuknya sengaja berbeda lagi dari dua keadaan kosong di bawahnya — ikon di
/// dalam kotak, judul, satu kalimat — supaya tiga bagian yang kebetulan kosong
/// bersamaan tidak terbaca sebagai satu blok yang berulang tiga kali.
class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: <Widget>[
          AppIconBox(
            icon: Icons.history_rounded,
            size: 40,
            foreground: palette.textMuted,
            background: palette.surfaceSubtle,
            borderColor: palette.borderSubtle,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Belum ada pengajuan', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Izin dan cuti yang Anda ajukan akan muncul di sini.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < 2; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            const Row(
              children: <Widget>[
                AppSkeleton(
                  width: 40,
                  height: 40,
                  borderRadius: AppRadii.xlAll,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AppSkeleton(width: 120, height: 13),
                      SizedBox(height: AppSpacing.sm),
                      AppSkeleton(width: 160, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
