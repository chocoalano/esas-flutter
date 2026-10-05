/// Terjemahan tunggal untuk seluruh kosakata absensi.
///
/// Server berbicara dalam huruf kapital Inggris — `ON_TIME`, `LATE`, `MANUAL`,
/// `QR`, `ABSENT` — dan layar berbahasa Indonesia. Sebelum berkas ini ada,
/// terjemahannya hidup sebagai tiga fungsi privat di dalam satu kartu daftar,
/// sehingga sheet rinciannya menuliskan sendiri versi yang lebih miskin:
/// hanya `LATE` yang diterjemahkan, sisanya dicetak apa adanya. Satu kode
/// status baru dari server dan dua layar akan tidak sepakat.
///
/// Semua yang di sini berupa fungsi tingkat atas tanpa ketergantungan pada
/// widget, jadi baris ledger, sheet rincian, dan panel Beranda memanggil yang
/// sama persis.
library;

import 'dart:ui' show Color;

import 'package:intl/intl.dart';

import '../../../core/tenancy/workspace_clock.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/ui/components/app_badge.dart';

/// Nilai jam yang tidak tercatat. Bukan "00:00": jam nol adalah jam yang nyata.
const String attendanceEmptyClock = '--:--';

/// Nilai kosong sebuah baris rincian.
const String attendanceEmptyValue = '—';

/// `08:11:04` menjadi `08:11`.
///
/// Detik tidak pernah menjadi bahan pertimbangan siapa pun yang membaca riwayat
/// kehadirannya sendiri, dan dua digit tambahan menggeser seluruh kolom.
String attendanceClock(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return attendanceEmptyClock;

  final parts = value.split(':');
  if (parts.length < 2) return value;

  return '${parts[0]}:${parts[1]}';
}

/// Apakah sebuah jam benar-benar terekam.
bool attendanceHasClock(String? raw) => (raw?.trim() ?? '').isNotEmpty;

/// Kode status kehadiran dalam bahasa Indonesia.
///
/// Kode yang tidak dikenal TIDAK dikembalikan apa adanya. Menampilkan
/// `HALF_DAY` kepada staf pabrik bukan informasi, dan kode mentah di layar
/// adalah cara sebuah enum server diam-diam menjadi antarmuka.
String attendanceStatusLabel(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case '':
      return attendanceEmptyValue;
    case 'LATE':
      return 'Terlambat';
    case 'ON_TIME':
    case 'ONTIME':
    case 'NORMAL':
      return 'Tepat waktu';
    case 'EARLY':
      return 'Lebih awal';
    // An administrator marked this excused, and that is the whole of what the
    // domain says.
    //
    // Audited rather than guessed from the name: NOTHING in the server produces
    // `unlate`. `RecordAttendance::status()` returns only `Normal` or `Late`,
    // no seeder or importer writes it, and the single way a row can hold it is
    // an administrator choosing it on the attendance form. The enum's own
    // `label()` says "Excused" and nothing narrows it further.
    //
    // So NOT "Terlambat dimaafkan", which this said first. That claims the
    // punch was late and then forgiven, and an administrator can set `unlate`
    // on a row that was never marked late at all. The word has to stop where
    // the evidence does.
    case 'UNLATE':
      return 'Dimaafkan';
    case 'ABSENT':
      return 'Tidak hadir';
    case 'PERMIT':
    case 'IZIN':
      return 'Izin';
    case 'LEAVE':
      return 'Cuti';
    case 'SICK':
      return 'Sakit';
    case 'HOLIDAY':
      return 'Libur';
    default:
      return 'Tidak diketahui';
  }
}

/// Label Indonesia untuk sebuah KODE status, atau `null` bila [raw] bukan
/// salah satu kode yang dikenal.
///
/// Kolom `status_in` yang sama dikirim server kadang sebagai kode (`LATE`) dan
/// kadang sebagai kalimat siap tampil ("Terlambat 12 menit"). [attendanceStatusLabel]
/// tidak bisa membedakan keduanya — sebuah kalimat yang sah akan dijawabnya
/// "Tidak diketahui". Fungsi ini menjawab pertanyaan yang berbeda: *apakah ini
/// sebuah kode?* Pemanggil yang menerima kedua bentuk memakai ini dulu, lalu
/// jatuh ke kalimatnya sendiri bila jawabannya `null`.
String? attendanceStatusCodeLabel(String? raw) {
  final String key = (raw ?? '').trim().toUpperCase();

  if (key.isEmpty) return null;

  const Set<String> known = {
    'LATE',
    'ON_TIME',
    'ONTIME',
    'NORMAL',
    'EARLY',
    'ABSENT',
    'PERMIT',
    'IZIN',
    'LEAVE',
    'SICK',
    'HOLIDAY',
  };

  return known.contains(key) ? attendanceStatusLabel(key) : null;
}

/// Nada semantik sebuah status kehadiran.
AppBadgeTone attendanceStatusTone(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'LATE':
      return AppBadgeTone.warning;
    case 'ABSENT':
      return AppBadgeTone.danger;
    case 'ON_TIME':
    case 'ONTIME':
    case 'NORMAL':
    case 'EARLY':
    case 'UNLATE':
      return AppBadgeTone.success;
    case 'PERMIT':
    case 'IZIN':
    case 'LEAVE':
    case 'SICK':
    case 'HOLIDAY':
      return AppBadgeTone.info;
    default:
      return AppBadgeTone.neutral;
  }
}

/// Cara sebuah absensi direkam.
///
/// ## Nilai yang benar-benar ada
///
/// `App\Enums\Hrms\AttendanceMethod` hanya punya tiga:
///
/// * `qrcode` — kode QR departemen atau mesin;
/// * `face-geolocation` — pindai wajah yang koordinatnya ikut terekam;
/// * `face-device` — pindai wajah tanpa koordinat.
///
/// Yang terakhir dua adalah keputusan `RecordAttendance::faceMethod()`: klaim
/// yang lebih kuat hanya dicatat bila lokasinya memang diukur.
///
/// Versi sebelumnya memetakan `MANUAL`, `GPS`, `LOCATION` dan `FACE` — empat
/// nilai yang tidak pernah dikirim server — sementara `face-device` dan
/// `face-geolocation`, dua dari tiga nilai yang benar-benar ada, jatuh ke
/// "Metode lain". Sheet rincian karena itu menolak menyebut cara absensi wajah
/// direkam, yaitu pertanyaan pertama ketika sebuah punch dipersoalkan.
///
/// Kode yang tidak dikenal TIDAK dikembalikan apa adanya: `HALF_DAY` di layar
/// staf pabrik bukan informasi, dan enum server bukan antarmuka.
String attendanceMethodLabel(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case '':
      return attendanceEmptyValue;
    case 'QRCODE':
    case 'QR':
    case 'QR_CODE':
      return 'Pindai QR';
    case 'FACE-GEOLOCATION':
    case 'FACE_GEOLOCATION':
      return 'Pindai wajah + lokasi';
    case 'FACE-DEVICE':
    case 'FACE_DEVICE':
    case 'FACE':
      return 'Pindai wajah';
    default:
      return 'Metode lain';
  }
}

/// Nada satu hari kehadiran: yang paling perlu diketahui dari dua punch.
///
/// Sebuah hari dengan masuk tepat waktu dan pulang terlambat adalah hari
/// terlambat; titik status hanya punya satu warna, jadi ia membawa yang paling
/// berkonsekuensi.
AppBadgeTone attendanceDayTone(String? statusIn, String? statusOut) {
  final tones = <AppBadgeTone>[
    attendanceStatusTone(statusIn),
    attendanceStatusTone(statusOut),
  ];

  for (final rank in const [
    AppBadgeTone.danger,
    AppBadgeTone.warning,
    AppBadgeTone.info,
    AppBadgeTone.success,
  ]) {
    if (tones.contains(rank)) return rank;
  }

  return AppBadgeTone.neutral;
}

/// Warna penuh sebuah nada, untuk titik status dan ikon yang tidak berupa
/// lencana. Selalu lewat palet — tidak ada satu pun heks di layar absensi.
Color attendanceToneColor(AppBadgeTone tone, AppPalette palette) {
  return switch (tone) {
    AppBadgeTone.neutral => palette.neutral.foreground,
    AppBadgeTone.brand => palette.brandAccent,
    AppBadgeTone.success => palette.success.foreground,
    AppBadgeTone.warning => palette.warning.foreground,
    AppBadgeTone.danger => palette.danger.foreground,
    AppBadgeTone.info => palette.info.foreground,
  };
}

/// Dua makna yang sangat berbeda dari `--:--`.
///
/// Keduanya hari ini digambar sama persis, dan itu menyembunyikan cacat
/// payroll: sebuah punch lampau yang tidak pernah ditutup terbaca seperti hari
/// kerja yang sedang berjalan.
enum AttendanceGap {
  /// Hari ini, dan punch-nya memang masih terbuka.
  running,

  /// Tanggal lampau yang tidak pernah ditutup.
  missing,
}

extension AttendanceGapDisplay on AttendanceGap {
  /// The word for ONE PUNCH that is not there.
  ///
  /// A punch, not a day: the day-level word is [AttendanceVerdict]'s "Belum
  /// lengkap", and the two describe different grains rather than disagreeing.
  /// "Tidak tercatat" said neither clearly — on a clock-out block it reads as a
  /// verdict on the whole day.
  String get label => switch (this) {
    AttendanceGap.running => 'Berjalan',
    AttendanceGap.missing => 'Belum tercatat',
  };

  AppBadgeTone get tone => switch (this) {
    AttendanceGap.running => AppBadgeTone.brand,
    // Warning, not danger. A missing clock-out is a record to complete, and
    // nothing on this endpoint can tell it apart from a day somebody was
    // genuinely absent — red would be the screen deciding which.
    AttendanceGap.missing => AppBadgeTone.warning,
  };
}

/// Celah pada sebuah baris kehadiran, bila ada.
///
/// `null` berarti hari itu lengkap: kedua jamnya terekam.
AttendanceGap? attendanceGapOf({
  required String? timeIn,
  required String? timeOut,
  required String? datePresence,
}) {
  if (attendanceHasClock(timeIn) && attendanceHasClock(timeOut)) return null;

  return attendanceIsToday(datePresence)
      ? AttendanceGap.running
      : AttendanceGap.missing;
}

/// `yyyy-MM-dd` menjadi tanggal, atau null bila tidak terbaca.
DateTime? attendanceDate(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;

  return DateTime.tryParse(value);
}

/// Apakah baris ini bertanggal hari ini menurut jam workspace.
///
/// Jam ponsel adalah jawaban yang berbeda dan salah: menjelang tengah malam ia
/// menyeberangi batas hari lebih dulu atau lebih lambat daripada kantor yang
/// merekam absensinya.
bool attendanceIsToday(String? rawDate) {
  final date = attendanceDate(rawDate);
  if (date == null) return false;

  final now = WorkspaceClock.current.now();

  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

/// "Rab, 12 Mar 2026" — bentuk pendek untuk baris ledger.
String attendanceDateLabel(String? raw) {
  final date = attendanceDate(raw);
  if (date == null) return 'Tanggal tidak tercatat';

  return DateFormat('EEE, d MMM yyyy', 'id').format(date);
}

/// "Rabu, 12 Maret 2026" — bentuk panjang untuk judul sheet rincian.
/// The weekday as a three-letter code — `JUM`.
///
/// Upper case because it is an abbreviation rather than a word: `Jum` reads as
/// a truncated sentence, `JUM` reads as a label. Null when the date cannot be
/// parsed, so the badge is simply absent rather than showing a placeholder that
/// looks like a day.
String? attendanceWeekdayBadge(String? raw) {
  final date = attendanceDate(raw);
  if (date == null) return null;

  return DateFormat('EEE', 'id').format(date).toUpperCase();
}

/// The date without its weekday — `4 Sep 2026`.
///
/// Paired with [attendanceWeekdayBadge], which carries the day. Saying it twice
/// — `JUM` beside `Jum, 4 Sep 2026` — is the same fact competing with itself.
String attendanceDayLabel(String? raw) {
  final date = attendanceDate(raw);
  if (date == null) return 'Tanggal tidak tercatat';

  return DateFormat('d MMM yyyy', 'id').format(date);
}

String attendanceFullDateLabel(String? raw) {
  final date = attendanceDate(raw);
  if (date == null) return 'Tanggal tidak tercatat';

  return DateFormat('EEEE, d MMMM yyyy', 'id').format(date);
}

/// "MARET 2026" — judul kelompok bulan pada ledger.
String attendanceMonthLabel(DateTime date) {
  return DateFormat('MMMM yyyy', 'id').format(date);
}

/// Menit sejak tengah malam, untuk sparkline jam masuk. `null` bila tidak ada
/// punch — dan null itu MEMUTUS garis, bukan menariknya ke nol.
int? attendanceMinuteOfDay(String? rawTime) {
  final value = rawTime?.trim() ?? '';
  if (value.isEmpty) return null;

  final parts = value.split(':');
  if (parts.length < 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;

  return hour * 60 + minute;
}

/// Jarak antara dua punch, misalnya "8j 21m".
///
/// ## Mengapa jam pulang yang lebih kecil TIDAK selalu berarti lewat tengah
/// malam
///
/// Versi sebelumnya menambahkan satu hari pada setiap pasangan terbalik:
///
/// ```dart
/// final span = end >= start ? end - start : end + 24 * 60 - start;
/// ```
///
/// Untuk shift malam itu benar. Untuk data rusak — masuk 15:00, pulang 09:00
/// karena sebuah koreksi salah tulis — itu menghasilkan "18j 00m", sebuah angka
/// yang terlihat meyakinkan dan berasal dari baris yang justru sedang
/// dipersoalkan orang. Di layar yang dibuka untuk memeriksa apakah catatannya
/// benar, angka yang percaya diri dari data yang salah lebih buruk daripada
/// tidak ada angka.
///
/// Jadi pembalikan hanya diterima bila jadwalnya memang menyeberangi tengah
/// malam. [overnight] datang dari `Attendance.crossesMidnight`, yaitu
/// `shift_in`/`shift_out` yang dikirim server. Tanpa jadwal, jawabannya em dash
/// — dan tidak ada batas jam maksimum yang dikarang di sini, karena domain ini
/// tidak punya satu pun.
String attendanceDuration(
  String? timeIn,
  String? timeOut, {
  bool overnight = false,
}) {
  final start = attendanceMinuteOfDay(timeIn);
  final end = attendanceMinuteOfDay(timeOut);
  if (start == null || end == null) return attendanceEmptyValue;

  if (end >= start) {
    final span = end - start;

    return '${span ~/ 60}j ${(span % 60).toString().padLeft(2, '0')}m';
  }

  if (!overnight) return attendanceEmptyValue;

  final span = end + 24 * 60 - start;

  return '${span ~/ 60}j ${(span % 60).toString().padLeft(2, '0')}m';
}

/// What the roster called the day: `working`, `rest` or `holiday`.
///
/// Sent per row as `day_type`, and the only thing that can tell a rest day
/// apart from a day somebody failed to clock. Null for a payload that predates
/// the field.
String? attendanceDayTypeLabel(String? raw) =>
    switch ((raw ?? '').trim().toLowerCase()) {
      'rest' => 'Hari libur',
      'holiday' => 'Hari besar',
      _ => null,
    };

/// Whether the day was one the roster expected work on.
bool attendanceIsWorkingDay(String? dayType) =>
    (dayType ?? 'working').trim().toLowerCase() == 'working';

/// The status of a day, said only as strongly as the data supports.
///
/// ## Why this is not [attendanceStatusLabel]
///
/// `RecordAttendance::status()` returns `AttendanceStatus::Normal`
/// **unconditionally** when the day had no rostered shift:
///
/// ```php
/// $shift = $schedule?->timeWork;
/// if ($shift === null) {
///     return AttendanceStatus::Normal;
/// }
/// ```
///
/// The client then printed "Tepat waktu" for it. That is the screen answering a
/// question nobody could answer: a clock-in at 15:14 on a day with no shift is
/// not punctual and not late — there was nothing to be punctual against. Saying
/// "Tepat waktu" there is the difference between reporting a fact and inventing
/// one, on the screen an employee opens specifically to check whether their
/// attendance was recorded correctly.
///
/// So the schedule decides which vocabulary is available:
///
/// * with a shift — `Tepat waktu` / `Terlambat`, both measured;
/// * without one — `Tercatat`, which claims only what happened.
String attendanceStatusLabelFor(String? raw, {required bool hasSchedule}) {
  if (hasSchedule) return attendanceStatusLabel(raw);

  // Only punctuality needs a shift to be measured against. Sick, leave, permit
  // and absence are facts about the day itself, and a missing roster does not
  // make them any less true — downgrading them too would turn a week of sick
  // leave into a week of shrugs.
  return switch ((raw ?? '').trim().toUpperCase()) {
    'ON_TIME' || 'ONTIME' || 'NORMAL' || 'EARLY' || 'UNLATE' => 'Tercatat',
    _ => attendanceStatusLabel(raw),
  };
}

/// The same, for the clock-OUT status.
///
/// `RecordAttendance` marks an early departure with `AttendanceStatus::Late` —
/// the same enum value as arriving late, because it is "the same failure seen
/// from the other end". Printing the arrival word for it tells somebody they
/// were late when what happened is that they left early.
String attendanceOutStatusLabelFor(String? raw, {required bool hasSchedule}) {
  final normalised = (raw ?? '').trim().toUpperCase();

  if (normalised == 'LATE') {
    return 'Pulang awal';
  }

  return attendanceStatusLabelFor(raw, hasSchedule: hasSchedule);
}

/// The tone that goes with [attendanceStatusLabelFor].
///
/// Kept beside the label because the two must never disagree: green is the
/// screen saying "this was fine", and `Normal` on a day with no shift is not
/// the server saying that — it is the server saying it had nothing to compare
/// against. Neutral is the only honest colour for it.
AppBadgeTone attendanceStatusToneFor(String? raw, {required bool hasSchedule}) {
  if (hasSchedule) return attendanceStatusTone(raw);

  // Same rule as [attendanceStatusLabelFor], and deliberately in lockstep with
  // it: only the punctuality verdicts lose their colour.
  return switch ((raw ?? '').trim().toUpperCase()) {
    'ON_TIME' ||
    'ONTIME' ||
    'NORMAL' ||
    'EARLY' ||
    'UNLATE' => AppBadgeTone.neutral,
    _ => attendanceStatusTone(raw),
  };
}

/// The tone of one whole day, from both punches and the roster.
///
/// The rule is unchanged — the most consequential of the two punches wins,
/// because a dot has one colour — but each punch is now read through the
/// schedule, so an unrostered day can no longer come out green.
AppBadgeTone attendanceDayToneFor({
  required String? statusIn,
  required String? statusOut,
  required bool hasSchedule,
}) {
  final tones = <AppBadgeTone>[
    attendanceStatusToneFor(statusIn, hasSchedule: hasSchedule),
    attendanceStatusToneFor(statusOut, hasSchedule: hasSchedule),
  ];

  for (final rank in const [
    AppBadgeTone.danger,
    AppBadgeTone.warning,
    AppBadgeTone.info,
    AppBadgeTone.success,
  ]) {
    if (tones.contains(rank)) return rank;
  }

  return AppBadgeTone.neutral;
}

/// The rostered shift as one line — `Shift Pagi · 08:00–17:00`.
///
/// Null when the row carries no roster, which is the case this screen must be
/// able to show rather than paper over: a day with no shift line is a day whose
/// "Tercatat" has no schedule behind it, and the two absences explain each
/// other.
String? attendanceShiftLine({
  required String? shift,
  required String? shiftIn,
  required String? shiftOut,
}) {
  final String name = (shift ?? '').trim();
  final String start = attendanceClock(shiftIn);
  final String end = attendanceClock(shiftOut);

  final bool hasWindow =
      start != attendanceEmptyClock && end != attendanceEmptyClock;

  if (name.isEmpty && !hasWindow) return null;
  if (name.isEmpty) return '$start–$end';
  if (!hasWindow) return name;

  return '$name · $start–$end';
}

// The average clock-in used to be computed here, as a circular mean over the
// rows the phone happened to be holding. It has moved to the server —
// `App\Support\Hrms\AttendanceMonthlyTotals::averageClockIn()` — for two
// reasons, and only the second is about the maths.
//
// The first: a mean over page one is not a mean over the month the heading
// names, and no amount of care in the arithmetic fixes that.
//
// The second: the clustering floor below which the answer is withheld is a
// product decision, not a mathematical constant. A copy of it here and another
// in whatever reads this data next is two definitions of "usual arrival time",
// and the disagreement between them is the sort a payslip conversation runs
// aground on. There is one definition now, and it is the server's.

/// One thing that needs saying about a day, beyond "it was fine".
///
/// [label] is the word on a badge; [detail] is the same fact written out for
/// the supporting line, where there is room to say which end of the day it
/// happened at. They differ only where the shorter form would be ambiguous
/// standing next to another note — "Terlambat" alone is clear on a badge and
/// vague beside "Pulang awal".
class AttendanceNote {
  const AttendanceNote({required this.label, required this.detail});

  final String label;
  final String detail;
}

/// What one attendance day amounts to: one badge, and the notes behind it.
///
/// ## Why this is a type and not a pair of `if`s in the row widget
///
/// The same question is asked in three places — the ledger row, the detail
/// sheet, and the sentence a screen reader is given — and the three used to
/// answer it separately. That is how the row came to show "Tepat waktu" in
/// warning yellow: the colour was computed from both punches and the word from
/// the clock-in alone, by two expressions that had no reason to agree.
class AttendanceVerdict {
  const AttendanceVerdict({
    required this.label,
    required this.tone,
    this.notes = const <AttendanceNote>[],
  });

  /// The badge's word. With one note it IS that note; with several it counts
  /// them, because two badges on a ledger row is where a list stops being
  /// scannable.
  final String label;

  final AppBadgeTone tone;

  /// Everything the badge is standing in for. Empty when the label says all of
  /// it, which is the ordinary case — a clean day carries no notes and no
  /// supporting line.
  final List<AttendanceNote> notes;

  /// The supporting line, or null when the badge already said everything.
  String? get detail =>
      notes.length < 2 ? null : notes.map((note) => note.detail).join(' · ');
}

/// Read a day, and say only what its data supports.
///
/// The order is deliberate and every step of it is a claim about what matters
/// most to somebody scanning their own attendance:
///
/// 1. **A day still open** outranks everything. Today's clock-in with no
///    clock-out yet is not a problem, and last Tuesday's is the most
///    actionable thing on the screen.
/// 2. **Leave, sickness and absence** come from the server as their own
///    statuses and are facts about the day rather than measurements against a
///    shift, so they survive a missing roster.
/// 3. **Punctuality** is last, because it is the only part that needs a shift
///    to mean anything.
AttendanceVerdict attendanceVerdictOf({
  required String? statusIn,
  required String? statusOut,
  required String? timeIn,
  required String? timeOut,
  required String? datePresence,
  required bool hasSchedule,
}) {
  final String normalisedIn = (statusIn ?? '').trim().toUpperCase();
  final String normalisedOut = (statusOut ?? '').trim().toUpperCase();

  // A day nobody has finished yet.
  final AttendanceGap? gap = attendanceGapOf(
    timeIn: timeIn,
    timeOut: timeOut,
    datePresence: datePresence,
  );

  if (gap == AttendanceGap.running) {
    return const AttendanceVerdict(label: 'Berjalan', tone: AppBadgeTone.brand);
  }

  // A category the server named outright. Checked before punctuality because
  // "Sakit" is what happened; whether the shift was met is not the question.
  for (final status in <String>[normalisedIn, normalisedOut]) {
    if (const <String>{
      'ABSENT',
      'PERMIT',
      'IZIN',
      'LEAVE',
      'SICK',
      'HOLIDAY',
    }.contains(status)) {
      return AttendanceVerdict(
        label: attendanceStatusLabel(status),
        tone: attendanceStatusTone(status),
      );
    }
  }

  final notes = <AttendanceNote>[
    if (normalisedIn == 'LATE')
      const AttendanceNote(label: 'Terlambat', detail: 'Terlambat masuk'),
    // Early leaving is written by the server as `Late` on the OUT column — the
    // same enum value as arriving late, "the same failure seen from the other
    // end". Reading it as the arrival word tells somebody they were late when
    // what happened is that they left early.
    if (normalisedOut == 'LATE')
      const AttendanceNote(label: 'Pulang awal', detail: 'Pulang awal'),
    if (gap == AttendanceGap.missing)
      const AttendanceNote(
        label: 'Belum lengkap',
        detail: 'Belum ada jam pulang',
      ),
  ];

  if (notes.length == 1) {
    return AttendanceVerdict(
      label: notes.first.label,
      tone: AppBadgeTone.warning,
      notes: notes,
    );
  }

  if (notes.length > 1) {
    // Counted rather than listed. Two badges on one row is the point at which a
    // ledger stops being scannable, and the line underneath has room to say
    // both without competing with the date.
    return AttendanceVerdict(
      label: '${notes.length} catatan',
      tone: AppBadgeTone.warning,
      notes: notes,
    );
  }

  // A lateness an administrator marked excused. Nothing in the server produces
  // `unlate` — see [attendanceStatusLabel] — so this only ever arrives by hand.
  if (normalisedIn == 'UNLATE' || normalisedOut == 'UNLATE') {
    return const AttendanceVerdict(
      label: 'Dimaafkan',
      tone: AppBadgeTone.success,
    );
  }

  if (normalisedIn.isEmpty && !attendanceHasClock(timeIn)) {
    return const AttendanceVerdict(
      label: 'Tidak tercatat',
      tone: AppBadgeTone.neutral,
    );
  }

  // Nothing went wrong. Whether that amounts to *punctuality* depends on there
  // having been a shift to be punctual against.
  return hasSchedule
      ? const AttendanceVerdict(
          label: 'Tepat waktu',
          tone: AppBadgeTone.success,
        )
      : const AttendanceVerdict(label: 'Tercatat', tone: AppBadgeTone.neutral);
}
