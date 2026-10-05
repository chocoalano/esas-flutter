import 'package:esas/features/permit/data/models/schedule.dart';
import 'package:esas/features/permit/presentation/controllers/permit_create_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Formulir pengajuan izin: jam dan pilihan jadwalnya.
///
/// Empat bug nyata dijaga di sini, ketiganya berasal dari satu sumber yang
/// sama — pemilih jam menuliskan hasilnya lewat `TimeOfDay.format`, dan pada
/// locale Indonesia bentuknya `08.45`, bukan `08:45`:
///
/// 1. `createPermit` membersihkan titik itu untuk `start_time` dan `end_time`
///    saja. `timein_adjust` dan `timeout_adjust` berangkat apa adanya, jadi
///    jenis izin penyesuaian jam selalu mengirim jam yang tidak lolos
///    `date_format:H:i` di server.
/// 2. "Jam pulang harus setelah jam masuk" dibandingkan sebagai teks, dengan
///    satu sisi sudah dibersihkan dan satu sisi belum. `':'` (0x3A) lebih besar
///    daripada `'.'` (0x2E), jadi 08:30 lolos sebagai "setelah" 08.45.
/// 3. `pickTime` memulihkan jam yang sudah dipilih dengan `text.split(':')`,
///    yang tidak pernah menemukan titik dua dan selalu jatuh ke jam sekarang.
/// 4. Baris jadwal kerja diurai dengan cast mentah, sehingga baris yang tidak
///    mengirim `user_id` lenyap diam-diam dari dropdown.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('penguraian jam', () {
    test('menerima bentuk bertitik yang ditulis pemilih jam', () {
      expect(PermitCreateController.minutesOfDay('08.45'), 8 * 60 + 45);
      expect(PermitCreateController.minutesOfDay('08:45'), 8 * 60 + 45);
      expect(PermitCreateController.minutesOfDay(' 8:45 '), 8 * 60 + 45);
    });

    test('menolak yang bukan jam', () {
      expect(PermitCreateController.minutesOfDay(''), isNull);
      expect(PermitCreateController.minutesOfDay('24:00'), isNull);
      expect(PermitCreateController.minutesOfDay('08:60'), isNull);
      expect(PermitCreateController.minutesOfDay('pagi'), isNull);
    });

    test('payload selalu HH:mm, apa pun bentuk yang diketik', () {
      expect(PermitCreateController.canonicalTime('08.45'), '08:45');
      expect(PermitCreateController.canonicalTime('8:45'), '08:45');
      expect(PermitCreateController.canonicalTime('sembarang'), '');
    });

    test('urutan dua jam tidak lagi bergantung pada pemisahnya', () {
      // Pasangan inilah yang dulu lolos: jam pulang 08.30 diterima sebagai
      // "setelah" jam masuk 08.45.
      final masuk = PermitCreateController.minutesOfDay('08.45')!;
      final pulang = PermitCreateController.minutesOfDay('08.30')!;

      expect(pulang, lessThan(masuk));
      expect(
        '08:30'.compareTo('08.45'),
        greaterThan(0),
        reason: 'perbandingan teks memberi jawaban sebaliknya',
      );
    });

    test('jam yang sudah dipilih bisa dipulihkan oleh pemilih', () {
      expect(PermitCreateController.minutesOfDay('08.45'), isNotNull);
      expect(
        '08.45'.split(':').length,
        1,
        reason: 'cara lama tidak pernah menemukan dua bagian',
      );
    });
  });

  group('baris jadwal kerja', () {
    test('diurai dari bentuk yang benar-benar dikirim /permits/form', () {
      // Bentuk itu tidak punya `user_id` maupun `time_work_id`; model ini dulu
      // menuntut keduanya dengan `as int`, jadi setiap baris gagal diurai dan
      // dropdown jadwal kerja selalu kosong.
      final schedule = Schedule.fromJson({
        'id': 12,
        'work_day': '2025-07-10',
        'shift_id': 3,
        'shift': 'Pagi',
        'in': '08:00:00',
        'out': '17:00:00',
        'attended': false,
      });

      expect(schedule.id, 12);
      expect(schedule.shiftId, 3);
      expect(schedule.formattedWorkDay, 'Kamis, 10 Juli 2025');
      // Detik dibuang; kolom jam membawanya dan layar tidak pernah memakainya.
      expect(schedule.optionLabel, 'Kamis, 10 Juli 2025 · Pagi 08:00–17:00');
    });

    test('hari yang sudah diabsen ditandai di dalam pilihannya', () {
      // Server mengirim `attended` justru supaya bisa dibaca sebelum memilih:
      // pengajuan atas hari yang sudah dijalani biasanya keliru.
      final schedule = Schedule.fromJson({
        'id': 12,
        'work_day': '2025-07-10',
        'attended': true,
      });

      expect(schedule.attended, isTrue);
      expect(schedule.optionLabel, endsWith('sudah absen'));
    });

    test('kunci lama `time_work_id` masih terbaca', () {
      expect(
        Schedule.fromJson({
          'id': 12,
          'work_day': '2025-07-10',
          'time_work_id': 7,
        }).shiftId,
        7,
      );
    });

    test('menerima id berupa string', () {
      expect(Schedule.fromJson({'id': '12', 'work_day': '2025-07-10'}).id, 12);
    });

    test('menolak baris tanpa tanggal alih-alih memasang tahun nol', () {
      expect(
        () => Schedule.fromJson({'id': 12, 'work_day': null}),
        throwsFormatException,
      );
    });
  });
}
