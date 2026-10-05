import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/features/attendance/presentation/attendance_labels.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:flutter/material.dart';

/// Jadwal hari ini sebagai garis waktu, dan absen sebagai pembandingnya.
///
/// Bagian ini adalah penerus panel jadwal lama, dan ia dipertahankan karena
/// membawa satu hal yang tidak dibawa panel protagonis di atasnya: **selisih**.
/// Kartu utama menjawab "sudah berapa lama saya bekerja"; yang ini menjawab
/// "apakah saya sesuai jadwal", dan keduanya bukan pertanyaan yang sama.
///
/// Selisih hitungan selalu didahulukan daripada kalimat status dari server,
/// karena ia deterministik dan bisa dibandingkan antarhari. Kalimat server
/// dipakai hanya ketika jadwalnya tidak diketahui sehingga tidak ada yang bisa
/// dihitung — dan ia tetap data yang sudah dibayar setiap rilis, jadi
/// membuangnya akan lebih buruk daripada menampilkannya.
class TodayTimeline extends StatelessWidget {
  const TodayTimeline({
    super.key,
    required this.scheduleIn,
    required this.scheduleOut,
    required this.timeIn,
    required this.timeOut,
    required this.statusIn,
    required this.statusOut,
  });

  final String? scheduleIn;
  final String? scheduleOut;
  final String? timeIn;
  final String? timeOut;
  final String? statusIn;
  final String? statusOut;

  /// Apakah ada sesuatu untuk digambar sama sekali.
  ///
  /// Dipakai pemanggil untuk memutuskan apakah bagian ini beserta judulnya ikut
  /// muncul. Sebuah bagian berjudul "Jadwal hari ini" yang isinya dua em dash
  /// adalah judul yang menjanjikan sesuatu yang tidak ada.
  bool get hasContent =>
      scheduleIn != null ||
      scheduleOut != null ||
      timeIn != null ||
      timeOut != null;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[
      _TimelineRow(
        planned: scheduleIn,
        title: 'Masuk kerja',
        actual: timeIn,
        delta: _delta(timeIn, scheduleIn, statusIn, late: true),
        isFirst: true,
        isLast: false,
      ),
      _TimelineRow(
        planned: scheduleOut,
        title: 'Pulang',
        actual: timeOut,
        delta: _delta(timeOut, scheduleOut, statusOut, late: false),
        isFirst: false,
        isLast: true,
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// Selisih terhadap jadwal, atau kalimat status server bila tidak terhitung.
  static _Delta? _delta(
    String? actual,
    String? scheduled,
    String? sentence, {
    required bool late,
  }) {
    final int? diff = HomeController.deltaMinutes(actual, scheduled);

    if (diff == null) {
      if (sentence == null) return null;

      // `status_in` datang kadang sebagai kode (`LATE`) dan kadang sebagai
      // kalimat siap tampil. Kode diterjemahkan lewat kamus yang sama yang
      // dipakai ledger absensi — beranda pernah mencetak `LATE` apa adanya,
      // berwarna netral, untuk hari yang di ledger berbunyi "Terlambat"
      // berwarna peringatan.
      final String? code = attendanceStatusCodeLabel(sentence);

      if (code != null) {
        return _Delta(code, attendanceStatusTone(sentence));
      }

      return _Delta(sentence, _sentenceTone(sentence));
    }

    if (diff == 0) {
      return const _Delta('tepat waktu', AppBadgeTone.success);
    }

    final String text = diff > 0
        ? '+${HomeController.spanLabel(diff)}'
        : '-${HomeController.spanLabel(-diff)}';

    // Terlambat masuk dan pulang lebih awal sama-sama perlu dilihat; datang
    // lebih awal dan pulang lebih lambat tidak.
    final bool notable = late ? diff > 0 : diff < 0;

    return _Delta(text, notable ? AppBadgeTone.warning : AppBadgeTone.neutral);
  }

  /// Menerjemahkan kalimat bebas dari server menjadi nada warna.
  ///
  /// Server mengirim kalimat ("Tepat waktu", "Terlambat 12 menit"), bukan kode,
  /// jadi pencocokan kata dilakukan di lapisan tampilan. Yang tidak dikenali
  /// sengaja jatuh ke netral daripada diwarnai secara keliru.
  static AppBadgeTone _sentenceTone(String status) {
    final String s = status.toLowerCase();

    if (s.contains('lambat') || s.contains('telat')) {
      return AppBadgeTone.warning;
    }

    if (s.contains('alpha') ||
        s.contains('alfa') ||
        s.contains('bolos') ||
        s.contains('tidak hadir')) {
      return AppBadgeTone.danger;
    }

    if (s.contains('tepat') ||
        s.contains('normal') ||
        s.contains('hadir') ||
        s.contains('sesuai')) {
      return AppBadgeTone.success;
    }

    if (s.contains('izin') || s.contains('cuti') || s.contains('sakit')) {
      return AppBadgeTone.info;
    }

    return AppBadgeTone.neutral;
  }
}

class _Delta {
  const _Delta(this.label, this.tone);

  final String label;
  final AppBadgeTone tone;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.planned,
    required this.title,
    required this.actual,
    required this.delta,
    required this.isFirst,
    required this.isLast,
  });

  final String? planned;
  final String title;
  final String? actual;
  final _Delta? delta;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    // Titik terisi berarti sudah terjadi. Bentuk, bukan warna, jadi ia tetap
    // terbaca pada layar monokrom.
    final bool happened = actual != null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Rail(happened: happened, isFirst: isFirst, isLast: isLast),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        planned ?? '--:--',
                        style: AppTypography.dataSmall(
                          color: planned == null
                              ? palette.textMuted
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // `Wrap` dan bukan `Row`: jam plus lencana selisih pada skala
                  // teks 1,5 di 320dp tidak muat berdampingan, dan yang benar
                  // adalah turun baris, bukan terpotong.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      Text(
                        actual ?? 'belum tercatat',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                      if (delta != null)
                        AppBadge(
                          label: delta!.label,
                          tone: delta!.tone,
                          dense: true,
                        ),
                    ],
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

/// Rel garis waktu: titik, dan garis penghubung ke baris berikutnya.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.happened,
    required this.isFirst,
    required this.isLast,
  });

  final bool happened;
  final bool isFirst;
  final bool isLast;

  static const double _dot = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return SizedBox(
      width: _dot,
      child: Column(
        children: <Widget>[
          Container(
            width: _dot,
            height: _dot,
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            decoration: BoxDecoration(
              color: happened
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: happened
                    ? theme.colorScheme.primary
                    : palette.borderStrong,
                width: 2,
              ),
            ),
          ),
          if (!isLast)
            Expanded(child: Container(width: 2, color: palette.borderSubtle)),
        ],
      ),
    );
  }
}
