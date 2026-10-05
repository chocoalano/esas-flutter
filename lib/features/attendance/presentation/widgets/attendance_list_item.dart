import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/features/attendance/data/models/attendance.dart';
import 'package:esas/features/attendance/presentation/attendance_labels.dart';
import 'package:flutter/material.dart';

/// Satu hari kehadiran, sebagai baris ledger.
///
/// ## Sejarah singkat
///
/// Kartu pertama setinggi 176dp: judul tanggal, nama karyawan, lalu dua kolom
/// berisi label, jam, lencana status, dan metode capture. Nama karyawannya
/// identik di setiap kartu selamanya — `attendance_repository.dart` tidak
/// mengirim id pegawai sama sekali, barisnya dipilih server dari token — jadi
/// kolom itu mengulang satu fakta yang sudah diketahui pembacanya.
///
/// Penggantinya memampatkannya menjadi 88dp: tanggal dengan titik status 6px,
/// `08:11 → 17:32`, dan sebuah chevron. Padat, tetapi terlalu pendiam untuk
/// pertanyaan yang dibawa orang ke layar ini.
///
/// ## Apa yang berubah sekarang, dan mengapa
///
/// * **`08:11 → 17:32` menjadi kolom berlabel.** Panah mengandalkan pembacanya
///   menebak arah; label tidak. Kolom ketiga menambahkan durasi — satu-satunya
///   angka di sini yang harus dihitung orang sendiri sebelumnya, dan yang
///   dihitung salah untuk shift malam bila dihitung di kepala.
/// * **Baris jadwal.** `shift`, `shift_in` dan `shift_out` sudah dikirim server
///   sejak lama dan dibuang model ini. Tanpanya, "Tepat waktu" adalah klaim
///   tanpa pembanding yang terlihat.
/// * **Titik status dihapus.** Titik 6px dan lencana di sebelahnya membawa nada
///   yang persis sama; latar lencana sudah berwarna, jadi kolom lencana tetap
///   bisa dipindai dari atas ke bawah. Satu nada, satu pembawa.
/// * **Lencana kini menyebut punch yang menentukan nadanya.** Sebelumnya
///   nadanya diambil dari kedua punch tetapi katanya hanya dari punch masuk,
///   jadi hari dengan masuk normal dan pulang awal terbaca "Tepat waktu"
///   berwarna kuning — sebuah kartu yang membantah dirinya sendiri.
class AttendanceListItem extends StatelessWidget {
  const AttendanceListItem({
    super.key,
    required this.attendance,
    required this.onTap,
  });

  final Attendance attendance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final AttendanceVerdict verdict = attendanceVerdictOf(
      statusIn: attendance.statusIn,
      statusOut: attendance.statusOut,
      timeIn: attendance.timeIn,
      timeOut: attendance.timeOut,
      datePresence: attendance.datePresence,
      hasSchedule: attendance.hasSchedule,
    );

    final String? meta = _metaLine(attendance);
    final String? weekday = attendanceWeekdayBadge(attendance.datePresence);

    // Hanya bila kedua punch ada DAN jaraknya bisa dihitung dengan jujur.
    // Sepasang jam terbalik pada hari tanpa shift malam adalah data rusak, dan
    // [attendanceDuration] menjawabnya dengan em dash alih-alih 18 jam.
    final String duration = attendanceDuration(
      attendance.timeIn,
      attendance.timeOut,
      overnight: attendance.crossesMidnight,
    );

    final bool showDuration =
        attendanceHasClock(attendance.timeIn) &&
        attendanceHasClock(attendance.timeOut) &&
        duration != attendanceEmptyValue;

    return Semantics(
      container: true,
      button: true,
      // Satu kalimat untuk seluruh baris, dengan urutan yang sama seperti
      // matanya membaca: hari, lalu status, lalu jamnya sebagai bukti.
      label: _spoken(attendance, verdict, duration, showDuration),
      child: ExcludeSemantics(
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // `Wrap`, bukan `Row`: pada 320dp dengan skala teks 1,5
                    // sebuah lencana "Terlambat dimaafkan" di samping tanggal
                    // lebih lebar daripada kartunya. Yang mengalah adalah
                    // barisnya — lencana turun ke bawah tanggal — bukan
                    // hurufnya, karena status yang dikecilkan sampai terbaca
                    // samar adalah status yang tidak dibaca.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (weekday != null)
                          _DayBadge(
                            weekday: weekday,
                            today: attendanceIsToday(attendance.datePresence),
                            ordinary: attendanceIsWorkingDay(
                              attendance.dayType,
                            ),
                          ),
                        Text(
                          attendanceDayLabel(attendance.datePresence),
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AppBadge(
                          label: verdict.label,
                          tone: verdict.tone,
                          dense: true,
                        ),
                      ],
                    ),
                    // Dua masalah dalam satu hari tidak muat pada satu lencana,
                    // dan dua lencana pada satu baris ledger adalah daftar yang
                    // berhenti bisa dipindai. Lencananya menghitung; baris ini
                    // yang menyebutkan.
                    if (verdict.detail case final detail?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.warning.foreground,
                        ),
                      ),
                    ],
                    if (meta != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        meta,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xxl,
                      runSpacing: AppSpacing.md,
                      children: [
                        _Punch(
                          label: 'Masuk',
                          value: attendanceClock(attendance.timeIn),
                          recorded: attendanceHasClock(attendance.timeIn),
                        ),
                        _Punch(
                          label: 'Pulang',
                          value: attendanceClock(attendance.timeOut),
                          recorded: attendanceHasClock(attendance.timeOut),
                        ),
                        // Durasi dari satu punch adalah angka yang dikarang.
                        if (showDuration)
                          _Punch(
                            label: 'Durasi',
                            value: duration,
                            recorded: true,
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

  /// Baris kedua: jenis hari menurut kalender kerja, lalu shift yang
  /// dijadwalkan.
  ///
  /// Keduanya boleh kosong, dan kekosongannya bermakna — sebuah hari tanpa
  /// baris ini adalah hari yang statusnya memang tidak punya pembanding.
  static String? _metaLine(Attendance attendance) {
    final parts = <String>[
      if (attendanceDayTypeLabel(attendance.dayType) case final label?) label,
      if (attendanceShiftLine(
            shift: attendance.shift,
            shiftIn: attendance.shiftIn,
            shiftOut: attendance.shiftOut,
          )
          case final line?)
        line,
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// The whole row as one sentence, in the order the eye reads it.
  static String _spoken(
    Attendance attendance,
    AttendanceVerdict verdict,
    String duration,
    bool showDuration,
  ) {
    final parts = <String>[
      attendanceFullDateLabel(attendance.datePresence),
      if (attendanceDayTypeLabel(attendance.dayType) case final label?) label,
      'Status ${verdict.label.toLowerCase()}',
      if (verdict.detail case final detail?) detail,
      'Masuk ${attendanceHasClock(attendance.timeIn) ? attendanceClock(attendance.timeIn) : 'belum tercatat'}',
      'Pulang ${attendanceHasClock(attendance.timeOut) ? attendanceClock(attendance.timeOut) : 'belum tercatat'}',
      if (showDuration) 'Durasi $duration',
    ];

    return '${parts.join('. ')}.';
  }
}

/// Nama hari sebagai jangkar visual.
///
/// Sebuah ledger dibaca dari atas ke bawah, dan yang dicari orang lebih dulu
/// adalah harinya — "Jumat kemarin bagaimana" — bukan tanggalnya. Sebagai teks
/// biasa di dalam kalimat `Jum, 4 Sep 2026`, hari itu punya berat yang sama
/// dengan angka di sebelahnya dan karena itu tidak bisa dipindai.
///
/// Tiga huruf kapital karena ini singkatan, bukan kata: `Jum` terbaca sebagai
/// kalimat yang terpotong, `JUM` terbaca sebagai label.
///
/// ## Nada
///
/// Bukan tujuh warna seperti kalender anak-anak. Hanya tiga keadaan, dan hanya
/// satu di antaranya berasal dari nama harinya:
///
/// * hari ini — rim brand, supaya baris paling atas punya jangkar;
/// * hari yang oleh kalender kerja BUKAN hari kerja — permukaan lebih redam;
/// * selebihnya netral.
///
/// Minggu tidak otomatis merah. Apakah sebuah tanggal hari libur adalah jawaban
/// `WorkCalendar` di server, dikirim sebagai `day_type` — dan sebuah perusahaan
/// yang bekerja enam hari seminggu punya hari Sabtu yang biasa saja.
class _DayBadge extends StatelessWidget {
  const _DayBadge({
    required this.weekday,
    required this.today,
    required this.ordinary,
  });

  final String weekday;
  final bool today;

  /// Apakah kalender kerja menyebut hari ini hari kerja biasa.
  final bool ordinary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final Color background = today
        ? palette.brandSubtle
        : (ordinary ? palette.surfaceSubtle : palette.neutral.background);
    final Color border = today
        ? theme.colorScheme.primary
        : palette.borderSubtle;
    final Color foreground = today
        ? theme.colorScheme.primary
        : (ordinary ? theme.colorScheme.onSurface : palette.textMuted);

    // Tanpa `alignment` dan tanpa lebar minimum. Sebuah `Container` yang diberi
    // `alignment` memuai sampai batas lebar yang diizinkan induknya — dan di
    // dalam `Wrap` batas itu adalah selebar kartu, jadi lencana tiga huruf ini
    // tergambar selebar barisnya. Ketujuh kode hari Indonesia sama panjang,
    // jadi ukuran mengikuti isi sudah menghasilkan kolom yang rata.
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: border),
      ),
      child: Text(
        weekday,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        maxLines: 1,
      ),
    );
  }
}

/// Sebuah label kecil di atas satu angka.
///
/// Labelnya di atas, bukan di bawah seperti kartu ringkasan bulan: di sana
/// angkanya adalah jawaban dan judulnya sekadar menyebut pertanyaannya, di sini
/// "Masuk" dan "Pulang" justru yang membedakan dua angka yang tampak serupa.
class _Punch extends StatelessWidget {
  const _Punch({
    required this.label,
    required this.value,
    required this.recorded,
  });

  final String label;
  final String value;

  /// `false` menggambar `--:--` dalam warna redam: sebuah punch yang tidak ada,
  /// bukan sebuah jam yang kebetulan nol.
  final bool recorded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Semantics(
      label: '$label $value',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              value,
              style: AppTypography.dataMedium(
                color: recorded
                    ? theme.colorScheme.onSurface
                    : palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
