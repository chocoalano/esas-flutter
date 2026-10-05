import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/widgets/home_metric.dart';
import 'package:flutter/material.dart';

/// Kehadiran bulan berjalan, sebagai angka — bukan sebagai kalimat.
///
/// Bagian ini pernah berbunyi "RINGKASAN BULAN INI / Belum ada kehadiran
/// tercatat bulan ini." dan tidak lebih. Secara data benar; sebagai dasbor ia
/// meminta orang MEMBACA untuk mengetahui sesuatu yang seharusnya bisa dilihat.
///
/// ## Apa yang boleh digambar, dan apa yang tidak
///
/// Server mengirim dua angka: `worked_days` dan `late_count`. Keduanya
/// hitungan hari, dan keduanya menjumlah tepat menjadi hari kerja — sehingga
/// sebuah bar dua nada di antara "tepat waktu" dan "terlambat" adalah gambar
/// yang benar secara aritmetika, bukan hiasan.
///
/// Yang TIDAK digambar adalah persentase kehadiran, cincin, atau "98%".
/// Penyebutnya adalah hari kerja yang DIHARAPKAN, dan tidak ada endpoint yang
/// mengirimkannya. Sebuah persentase yang penyebutnya dikarang adalah angka
/// salah yang terlihat persis seperti angka benar.
class HomeMonthlySnapshot extends StatelessWidget {
  const HomeMonthlySnapshot({
    super.key,
    required this.summary,
    required this.loading,
    required this.onOpen,
  });

  final MonthSummary? summary;
  final bool loading;

  /// Menuju riwayat absensi. Chevron di judul bagian hanya digambar kalau ini
  /// benar-benar menavigasi ke suatu tempat.
  final VoidCallback onOpen;

  /// Apakah bagian ini beserta judulnya ikut digambar.
  ///
  /// `null` berarti gagal dimuat, dan bagian sekunder yang gagal menghilang
  /// tanpa satu kata pun — kegagalannya sudah tercatat di log.
  bool get hasContent => loading || summary != null;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _SnapshotSkeleton();
    }

    final MonthSummary? data = summary;

    if (data == null) return const SizedBox.shrink();

    // Berhasil dimuat, dan jawabannya nol hari kerja: karyawan baru, atau bulan
    // yang belum dimulai. Itu FAKTA, bukan ketiadaan — dan tiga ubin berisi nol
    // adalah cara yang salah untuk menyampaikannya.
    if (!data.hasData) {
      return const _EmptyMonth();
    }

    return _Populated(data: data, onOpen: onOpen);
  }
}

class _Populated extends StatelessWidget {
  const _Populated({required this.data, required this.onOpen});

  final MonthSummary data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;
    final bool late = data.lateCount > 0;

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: HomeMetric(
                  value: '${data.workedDays}',
                  unit: 'hari',
                  label: 'Hari kerja',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: HomeMetric(
                  value: '${data.lateCount}',
                  unit: late ? 'hari' : null,
                  label: 'Terlambat',
                  // Nol keterlambatan bukan kabar buruk, jadi ia tidak diwarnai
                  // peringatan. Warna hanya muncul ketika ada yang benar-benar
                  // perlu dilihat.
                  tone: late ? palette.warning : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          HomeSplitBar(
            primary: data.onTimeDays,
            secondary: data.lateCount,
            primaryTone: palette.success,
            secondaryTone: palette.warning,
            semanticsLabel:
                '${data.onTimeDays} hari tepat waktu, '
                '${data.lateCount} hari terlambat, '
                'dari ${data.workedDays} hari kerja',
          ),
          const SizedBox(height: AppSpacing.sm),
          // Bar memberi bentuk, baris ini memberi nilai persisnya — dan tanpa
          // baris ini keadaan tetap tidak terbaca oleh mata yang tidak
          // membedakan hijau dari kuning.
          Row(
            children: <Widget>[
              _Legend(
                tone: palette.success,
                text: '${data.onTimeDays} tepat waktu',
              ),
              const SizedBox(width: AppSpacing.lg),
              if (late)
                _Legend(
                  tone: palette.warning,
                  text: '${data.lateCount} terlambat',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.tone, required this.text});

  final AppTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            decoration: BoxDecoration(
              color: tone.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.tight),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bulan yang berhasil dimuat dan memang belum punya hari kerja.
///
/// **Kalimatnya hanya boleh diucapkan setelah respons 200.** Ringkasan yang
/// GAGAL dimuat tidak pernah sampai ke sini — pemanggil menyembunyikan seluruh
/// bagiannya — dan itu bukan kerapian melainkan kejujuran: "belum ada aktivitas
/// bulan ini" adalah klaim tentang karyawannya, dan sebuah permintaan yang
/// ditolak tidak memberi kita hak untuk mengucapkannya.
///
/// Bentuknya sengaja BERBEDA dari keadaan kosong sisa cuti di bawahnya —
/// permukaan terisi tanpa garis, ikon di dalam kotak, dan nama bulan sebagai
/// penanda — supaya dua bagian yang kebetulan kosong bersamaan tidak terbaca
/// sebagai satu blok yang berulang.
class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: AppRadii.xxlAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppIconBox(
                icon: Icons.calendar_month_outlined,
                size: 40,
                foreground: palette.textMuted,
                background: theme.colorScheme.surface,
                borderColor: palette.borderSubtle,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  // Bulan berjalan pada jam KANTOR, bukan jam ponsel. Ia satu-
                  // satunya orientasi yang tersisa ketika angkanya belum ada.
                  DateFormatter.nowFormatted('MMMM yyyy'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Belum ada aktivitas kehadiran',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Angkanya muncul setelah kehadiran pertama tercatat.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rangka yang bentuknya menyerupai isinya, supaya halaman tidak melompat
/// ketika datanya mendarat.
class _SnapshotSkeleton extends StatelessWidget {
  const _SnapshotSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = Theme.of(context).palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadii.xlAll,
        border: Border.all(color: palette.borderSubtle),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppSkeleton(width: 56, height: 30),
                    SizedBox(height: AppSpacing.sm),
                    AppSkeleton(width: 72, height: 11),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppSkeleton(width: 40, height: 30),
                    SizedBox(height: AppSpacing.sm),
                    AppSkeleton(width: 64, height: 11),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(
            width: double.infinity,
            height: 8,
            borderRadius: AppRadii.pillAll,
          ),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(width: 140, height: 11),
        ],
      ),
    );
  }
}
