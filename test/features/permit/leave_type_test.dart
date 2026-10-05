import 'package:esas/features/permit/data/models/leave_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Penguraian jenis perizinan, dari dua generasi kontrak API.
///
/// Dua bug nyata dijaga di sini:
///
/// 1. Model ini dulu memakai cast mentah untuk setiap field, jadi satu baris
///    dengan `type: null` melempar
///    `type 'Null' is not a subtype of type 'String' in type cast` — sebuah
///    `TypeError`, bukan `ApiException`, yang melewati `catch` di
///    `PermitController` dan mengosongkan seluruh tab Pengajuan.
/// 2. Model ini hanya paham kosakata backend lama (`type`, `is_payed`,
///    `with_file`). Backend baru mengirim `name`, `requires_attachment`,
///    `is_active` — tidak satu pun kunci yang sama — sehingga **setiap** baris
///    tampil sebagai "Jenis izin tanpa nama".
void main() {
  group('kontrak baru (tabel leave_types)', () {
    test('membaca nama dari `name`', () {
      final type = LeaveType.fromJson({
        'id': 4,
        'code': 'ANNUAL',
        'name': 'Cuti Tahunan',
        'description': 'Mengurangi saldo cuti tahunan.',
        'requires_attachment': false,
        'is_active': true,
      });

      expect(type.type, 'Cuti Tahunan');
      expect(type.code, 'ANNUAL');
      expect(type.description, 'Mengurangi saldo cuti tahunan.');
      expect(type.withFile, isFalse);
      expect(type.showMobile, isTrue);
    });

    test('`requires_attachment` dipetakan ke withFile', () {
      final type = LeaveType.fromJson({
        'id': 5,
        'name': 'Sakit',
        'requires_attachment': true,
      });

      expect(type.withFile, isTrue);
    });

    test('status upah tidak ditebak ketika server tidak mengatakannya', () {
      final type = LeaveType.fromJson({
        'id': 6,
        'name': 'Izin',
        // `deducts_balance` menjawab pertanyaan yang berbeda dari "dibayar",
        // jadi ia sengaja tidak dipetakan ke sana.
        'deducts_balance': true,
      });

      expect(type.isPayed, isNull);
    });
  });

  group('kontrak lama (tabel permit_types)', () {
    test('masih membaca nama dari `type`', () {
      final type = LeaveType.fromJson({
        'id': 7,
        'type': 'Cuti Menikah',
        'is_payed': true,
        'with_file': true,
        'show_mobile': true,
        'approve_line': true,
        'created_at': '2026-01-05T02:43:31.000Z',
      });

      expect(type.type, 'Cuti Menikah');
      expect(type.isPayed, isTrue);
      expect(type.withFile, isTrue);
      expect(type.showMobile, isTrue);
      expect(type.approveLine, isTrue);
      expect(type.createdAt, DateTime.parse('2026-01-05T02:43:31.000Z'));
    });

    test('menerima id dan boolean yang dikirim sebagai string atau angka', () {
      final type = LeaveType.fromJson({
        'id': '12',
        'type': 'Sakit',
        'is_payed': 1,
        'with_file': 'true',
        'show_mobile': 0,
      });

      expect(type.id, 12);
      expect(type.isPayed, isTrue);
      expect(type.withFile, isTrue);
      expect(type.showMobile, isFalse);
    });
  });

  group('baris yang cacat', () {
    test('nama yang null tidak lagi melempar', () {
      late LeaveType type;

      expect(() => type = LeaveType.fromJson({'id': 3}), returnsNormally);

      // Nama yang jelas-jelas salah, bukan string kosong: baris cacat harus
      // terlihat, bukan menghilang diam-diam.
      expect(type.type, 'Jenis izin tanpa nama');
      expect(type.id, 3);
    });

    test('bendera yang hilang jatuh ke pilihan paling berhati-hati', () {
      final type = LeaveType.fromJson({'id': 1, 'name': 'Izin'});

      // Tidak menuntut lampiran yang mungkin tidak diperlukan, dan tidak
      // menjanjikan upah yang mungkin tidak ada.
      expect(type.withFile, isFalse);
      expect(type.showMobile, isFalse);
      expect(type.isPayed, isNull);
    });

    test('tanggal yang cacat menjadi null, bukan hari ini', () {
      final type = LeaveType.fromJson({
        'id': 1,
        'name': 'Izin',
        'created_at': 'bukan tanggal',
        'updated_at': null,
      });

      // Sebuah tanggal keliru yang tampak masuk akal lebih buruk daripada
      // tanggal yang kosong (R-10).
      expect(type.createdAt, isNull);
      expect(type.updatedAt, isNull);
    });
  });

  test('bolak-balik lewat toJson bisa dibaca kedua kontrak', () {
    final original = LeaveType.fromJson({
      'id': 4,
      'name': 'Dinas Luar',
      'code': 'TRIP',
      'requires_attachment': true,
      'is_active': true,
      'created_at': '2026-03-01T00:00:00.000Z',
    });

    final encoded = original.toJson();
    expect(encoded['name'], 'Dinas Luar');
    expect(encoded['type'], 'Dinas Luar');

    final restored = LeaveType.fromJson(encoded);
    expect(restored.type, original.type);
    expect(restored.code, original.code);
    expect(restored.withFile, original.withFile);
    expect(restored.isPayed, original.isPayed);
    expect(restored.createdAt, original.createdAt);
  });
}
