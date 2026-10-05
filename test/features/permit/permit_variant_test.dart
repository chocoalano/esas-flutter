import 'package:esas/features/permit/data/models/leave_type.dart';
import 'package:esas/features/permit/data/models/permit_variant.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jenis izin mana yang membuka formulir mana.
///
/// Yang dijaga di sini satu hal, dan itu yang paling mahal dari seluruh fitur
/// perizinan: aplikasi ini dulu mengenali dua jenis izin istimewa lewat kunci
/// primer — `permit_type_id` 15 berarti penyesuaian jam, 16 berarti tukar
/// shift. Angka itu hanya benar pada satu basis data. Perusahaan lain yang
/// membuat jenis izinnya sendiri mendapat 15 dan 16 menunjuk apa pun yang
/// kebetulan dibuat kelima belas dan keenam belas, dan karyawan yang butuh
/// tukar shift disuguhi formulir yang salah tanpa cara untuk tahu.
void main() {
  group('identitas varian', () {
    test('dibaca dari `variant` yang sudah dihitung server', () {
      expect(
        PermitVariant.resolve(variant: 'shift_adjustment', id: 3),
        PermitVariant.shiftAdjustment,
      );
    });

    test('dibaca dari kode bisnis bila server belum menghitungnya', () {
      expect(
        PermitVariant.resolve(code: 'TIME_ADJUSTMENT', id: 3),
        PermitVariant.timeAdjustment,
      );
    });

    test('kode dibandingkan tanpa memperhatikan besar-kecil huruf', () {
      expect(
        PermitVariant.resolve(code: '  shift_adjustment '),
        PermitVariant.shiftAdjustment,
      );
    });

    test('kode yang tidak dikenal adalah izin biasa, bukan galat', () {
      expect(PermitVariant.resolve(code: 'ANNUAL'), PermitVariant.general);
      expect(PermitVariant.resolve(code: 'SICK'), PermitVariant.general);
    });

    test('kode mengalahkan id peninggalan', () {
      // Baris yang dulu berarti "penyesuaian jam" semata-mata karena idnya 15,
      // kini diberi kode sebagai cuti tahunan. Kodenya yang berlaku.
      expect(
        PermitVariant.resolve(code: 'ANNUAL', id: 15),
        PermitVariant.general,
      );
    });

    test('tanpa kode maupun varian, id peninggalan masih dipakai', () {
      // Perusahaan yang backendnya belum mengisi `permit_types.code`. Cabang
      // ini yang dihapus begitu setiap tenant sudah mengisinya.
      expect(PermitVariant.resolve(id: 15), PermitVariant.timeAdjustment);
      expect(PermitVariant.resolve(id: 16), PermitVariant.shiftAdjustment);
      expect(PermitVariant.resolve(id: 4), PermitVariant.general);
      expect(PermitVariant.resolve(), PermitVariant.general);
    });
  });

  /// Tes penerimaan yang membuktikan kemerdekaan dari kunci primer.
  group('id boleh berbeda di setiap tenant', () {
    test('penyesuaian jam pada id 52, tukar shift pada id 87', () {
      final timeAdjustment = LeaveType.fromJson({
        'id': 52,
        'name': 'Koreksi absensi',
        'code': 'TIME_ADJUSTMENT',
        'variant': 'time_adjustment',
      });

      final shiftAdjustment = LeaveType.fromJson({
        'id': 87,
        'name': 'Tukar shift',
        'code': 'SHIFT_ADJUSTMENT',
        'variant': 'shift_adjustment',
      });

      expect(timeAdjustment.variant, PermitVariant.timeAdjustment);
      expect(shiftAdjustment.variant, PermitVariant.shiftAdjustment);
    });

    test('dan id 15/16 di tenant itu adalah izin biasa', () {
      // Dua baris yang, di tenant lain, kebetulan memegang angka istimewa itu.
      // Karena keduanya punya kode sendiri, angkanya tidak berarti apa-apa.
      final fifteen = LeaveType.fromJson({
        'id': 15,
        'name': 'Cuti melahirkan',
        'code': 'MATERNITY',
        'variant': 'general',
      });

      expect(fifteen.variant, PermitVariant.general);
    });
  });

  group('kolom yang boleh diisi tiap varian', () {
    test('izin biasa tidak membawa satu pun kolom penyesuaian', () {
      expect(PermitVariant.general.fields, isEmpty);
    });

    test('penyesuaian jam hanya membawa dua jamnya', () {
      expect(PermitVariant.timeAdjustment.fields, [
        'timein_adjust',
        'timeout_adjust',
      ]);
    });

    test('penyesuaian shift hanya membawa dua shiftnya', () {
      expect(PermitVariant.shiftAdjustment.fields, [
        'current_shift_id',
        'adjust_shift_id',
      ]);
    });
  });
}
