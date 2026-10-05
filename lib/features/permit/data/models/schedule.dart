import 'package:intl/intl.dart';

import '../../../../core/utils/json_parsers.dart';

/// Satu baris jadwal kerja karyawan — pilihan pertama pada formulir pengajuan.
///
/// ## Kontraknya, bukan tebakan atas kontraknya
///
/// `GET /permits/form` mengirim baris seperti ini:
///
/// ```json
/// {"id": 8, "work_day": "2026-09-02", "shift_id": 3, "shift": "Pagi",
///  "in": "08:00:00", "out": "17:00:00", "attended": false}
/// ```
///
/// Model ini dulu menuntut `user_id` dan `time_work_id` dengan `as int`, dan
/// tidak satu pun dari keduanya ada di sana. `asModelList` menangkap
/// kegagalannya per baris, jadi tidak ada layar merah — hanya dropdown jadwal
/// kerja yang kosong pada setiap pengajuan, dengan pesan "Jadwal kerja wajib
/// diisi" di bawah daftar yang tidak mungkin diisi.
///
/// ## `user_id` tidak hilang; ia memang bukan urusan baris ini
///
/// Endpointnya hanya memulangkan jadwal milik pemegang token. Kepemilikan sudah
/// dipastikan oleh server sebelum barisnya dikirim, jadi sebuah kolom pemilik
/// di sini tidak menambah apa pun yang bisa diperiksa — dan sebuah formulir
/// yang menanyakan jadwal siapa adalah formulir yang bisa ditanyakan untuk
/// orang lain.
class Schedule {
  const Schedule({
    required this.id,
    required this.workDay,
    this.shiftId,
    this.shiftName,
    this.shiftIn,
    this.shiftOut,
    this.attended = false,
  });

  final int id;
  final DateTime workDay;

  /// Shift yang dijadwalkan pada hari itu, bila server menyebutkannya.
  final int? shiftId;
  final String? shiftName;
  final String? shiftIn;
  final String? shiftOut;

  /// Hari itu sudah punya catatan absensi.
  ///
  /// Dikirim server justru untuk ditampilkan: "Pengajuan atas hari yang sudah
  /// dijalani biasanya keliru, dan aplikasi bisa mengatakannya sebelum dikirim,
  /// bukan sesudah."
  final bool attended;

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final id = asInt(json['id']);

    if (id == null) {
      throw const FormatException('Baris jadwal kerja tanpa id');
    }

    return Schedule(
      id: id,
      workDay: _parseWorkDay(json['work_day']),
      // `shift_id` pada kontrak sekarang, `time_work_id` pada yang lama.
      shiftId: asInt(json['shift_id']) ?? asInt(json['time_work_id']),
      shiftName: asString(json['shift']),
      shiftIn: _hourMinute(asString(json['in'])),
      shiftOut: _hourMinute(asString(json['out'])),
      attended: asBool(json['attended']) ?? false,
    );
  }

  /// Tanggal kerja, atau lemparan bila tidak ada bentuk yang dikenali.
  ///
  /// Melempar dengan sengaja. Nilai pengganti yang dulu dipakai — `DateTime(0)`
  /// untuk tanggal yang kosong — memasang baris "Minggu, 01 Januari 0000" di
  /// dalam dropdown: sebuah pilihan yang bisa dipilih orang dan mengisi tanggal
  /// pengajuan dengan tahun nol. `asModelList` menangkap lemparan ini, mencatat
  /// barisnya, dan meneruskan sisanya.
  static DateTime _parseWorkDay(Object? raw) {
    final value = asString(raw);

    if (value == null) {
      throw const FormatException('Baris jadwal kerja tanpa tanggal kerja');
    }

    final iso = DateTime.tryParse(value);

    if (iso != null) {
      return iso;
    }

    // Bentuk yang pernah dikirim backend lama: "28 June 25 13:56:36" dan
    // "28 Jun 25 13:56:36".
    for (final formatter in [
      DateFormat('dd MMMM yy HH:mm:ss', 'id'),
      DateFormat('dd MMM yy HH:mm:ss', 'id'),
    ]) {
      try {
        return formatter.parse(value);
      } on FormatException {
        continue;
      }
    }

    throw FormatException('Tanggal kerja tidak dikenali', value);
  }

  /// `08:00:00` menjadi `08:00`. Kolom jam pada basis data membawa detik yang
  /// tidak pernah berarti apa pun di layar.
  static String? _hourMinute(String? raw) {
    if (raw == null) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);

    if (match == null) return raw;

    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
  }

  /// Contoh: "Kamis, 10 Juli 2025".
  String get formattedWorkDay =>
      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(workDay);

  /// Baris sebagaimana dibaca di dropdown: tanggal, shift, dan penanda bila
  /// hari itu sudah terlanjur diabsen.
  String get optionLabel {
    final buffer = StringBuffer(formattedWorkDay);

    if (shiftName != null) {
      buffer.write(' · $shiftName');

      if (shiftIn != null && shiftOut != null) {
        buffer.write(' $shiftIn–$shiftOut');
      }
    }

    if (attended) {
      buffer.write(' · sudah absen');
    }

    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'work_day': workDay.toIso8601String(),
    'shift_id': shiftId,
    'shift': shiftName,
    'in': shiftIn,
    'out': shiftOut,
    'attended': attended,
  };

  @override
  String toString() => 'Schedule(id: $id, workDay: $formattedWorkDay)';
}
