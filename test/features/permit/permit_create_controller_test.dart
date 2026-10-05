import 'package:esas/features/permit/data/models/leave_type.dart';
import 'package:esas/features/permit/data/models/permit_variant.dart';
import 'package:esas/features/permit/data/models/schedule.dart';
import 'package:esas/features/permit/data/repositories/permit_repository.dart';
import 'package:esas/features/permit/presentation/controllers/permit_create_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermitRepository extends Mock implements PermitRepository {}

/// Pemilih berkas yang menjawab apa pun yang diminta tes.
///
/// `extends`, bukan `implements`: `FilePicker` adalah `PlatformInterface` dan
/// hanya menerima instance yang memanggil konstruktornya.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.answer);

  final FilePickerResult? answer;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool useLegacyPicker = false,
  }) async => answer;
}

LeaveType typeOf({
  required int id,
  String? code,
  String? variant,
  bool withFile = false,
}) => LeaveType.fromJson({
  'id': id,
  'name': 'Jenis $id',
  if (code != null) 'code': code,
  if (variant != null) 'variant': variant,
  'requires_file': withFile,
});

/// Isi pengajuan sebelum ia berangkat.
///
/// Formulir ini melayani tiga jenis permintaan yang berbeda dengan satu
/// kumpulan field, dan dulu mengirim semuanya pada setiap pengajuan: cuti
/// tahunan pun membawa `current_shift_id` dan `adjust_shift_id` karena formulir
/// memilihkan shift pertama untuk kedua dropdown, lalu dua jam penyesuaian
/// ikut sebagai string kosong. Yang dijaga di sini: satu jenis izin hanya
/// membawa kolom yang memang miliknya.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('id_ID'));

  late _MockPermitRepository repository;
  late PermitCreateController controller;

  setUp(() {
    repository = _MockPermitRepository();
    when(
      () => repository.formData(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => const PermitFormData());

    controller = PermitCreateController(repository: repository);
    controller.startDateC.text = '2026-09-02';
    controller.endDateC.text = '2026-09-02';
    controller.startTimeC.text = '08:00';
    controller.endTimeC.text = '17:00';
    controller.selectedScheduleId.value = 8;
  });

  tearDown(Get.reset);

  void useType(LeaveType type) {
    controller.createType.value = type;
    controller.selectedPermitTypeId.value = type.id;
  }

  group('payload menurut varian', () {
    test('izin biasa tidak membawa satu pun kolom penyesuaian', () {
      useType(typeOf(id: 4, code: 'ANNUAL'));

      // Diisi seolah-olah tertinggal dari varian lain. Penyusunan payload
      // adalah batas terakhirnya, dan batas itu harus memegang sendiri.
      controller.timeinAdjustC.text = '08:00';
      controller.selectedCurrentShiftId.value = 1;
      controller.selectedAdjustShiftId.value = 2;

      final fields = controller.buildFields();

      expect(fields.containsKey('timein_adjust'), isFalse);
      expect(fields.containsKey('timeout_adjust'), isFalse);
      expect(fields.containsKey('current_shift_id'), isFalse);
      expect(fields.containsKey('adjust_shift_id'), isFalse);
      expect(fields['permit_type_id'], 4);
      expect(fields['start_date'], '2026-09-02');
      expect(fields['end_date'], '2026-09-02');
    });

    test('penyesuaian jam membawa jamnya saja, dalam bentuk HH:mm', () {
      useType(typeOf(id: 52, code: 'TIME_ADJUSTMENT'));

      // Persis yang ditulis pemilih jam pada locale Indonesia.
      controller.timeinAdjustC.text = '08.45';
      controller.timeoutAdjustC.text = '17.15';
      controller.selectedCurrentShiftId.value = 1;

      final fields = controller.buildFields();

      expect(fields['timein_adjust'], '08:45');
      expect(fields['timeout_adjust'], '17:15');
      expect(fields.containsKey('current_shift_id'), isFalse);
    });

    test('penyesuaian shift membawa dua shiftnya saja', () {
      useType(typeOf(id: 87, code: 'SHIFT_ADJUSTMENT'));

      controller.selectedCurrentShiftId.value = 3;
      controller.selectedAdjustShiftId.value = 5;
      controller.timeinAdjustC.text = '08:00';

      final fields = controller.buildFields();

      expect(fields['current_shift_id'], 3);
      expect(fields['adjust_shift_id'], 5);
      expect(fields.containsKey('timein_adjust'), isFalse);
    });

    test('jam mulai dan selesai selalu HH:mm apa pun yang ada di field', () {
      useType(typeOf(id: 4));

      controller.startTimeC.text = '8.5';
      controller.endTimeC.text = '17.00';

      final fields = controller.buildFields();

      expect(fields['start_time'], '');
      expect(fields['end_time'], '17:00');
    });
  });

  group('berganti varian tidak meninggalkan sisa', () {
    setUp(() => controller.onInit());

    test('shift → umum membuang kedua id shift', () {
      useType(typeOf(id: 87, code: 'SHIFT_ADJUSTMENT'));
      controller.selectedCurrentShiftId.value = 3;
      controller.selectedAdjustShiftId.value = 5;

      useType(typeOf(id: 4, code: 'ANNUAL'));

      expect(controller.selectedCurrentShiftId.value, isNull);
      expect(controller.selectedAdjustShiftId.value, isNull);
      expect(controller.buildFields().containsKey('current_shift_id'), isFalse);
    });

    test('jam → shift membuang kedua jam penyesuaian', () {
      useType(typeOf(id: 52, code: 'TIME_ADJUSTMENT'));
      controller.timeinAdjustC.text = '08:00';
      controller.timeoutAdjustC.text = '17:00';

      useType(typeOf(id: 87, code: 'SHIFT_ADJUSTMENT'));

      expect(controller.timeinAdjustC.text, isEmpty);
      expect(controller.timeoutAdjustC.text, isEmpty);
    });

    test('umum → jam membiarkan jamnya kosong sampai diisi', () {
      useType(typeOf(id: 4, code: 'ANNUAL'));
      useType(typeOf(id: 52, code: 'TIME_ADJUSTMENT'));

      expect(controller.timeinAdjustC.text, isEmpty);
      expect(controller.variant, PermitVariant.timeAdjustment);
    });
  });

  group('yang tidak bisa diperiksa satu field', () {
    test('jenis izin yang tidak dikenali menghentikan pengiriman', () {
      // Layar dibuka tanpa argumen — deep link, notifikasi, pemulihan state.
      expect(controller.preflightError(), contains('Jenis izin'));
    });

    test('lampiran wajib ditagih sebelum dikirim, bukan oleh server', () {
      useType(typeOf(id: 9, code: 'SICK', withFile: true));

      expect(controller.preflightError(), contains('wajib melampirkan'));

      controller.selectedFile.value = PlatformFile(
        name: 'surat.pdf',
        size: 1024,
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(controller.preflightError(), isNull);
    });

    test('penyesuaian jam butuh salah satu dari dua jamnya', () {
      useType(typeOf(id: 52, code: 'TIME_ADJUSTMENT'));

      expect(controller.preflightError(), contains('minimal satu jam'));

      controller.timeoutAdjustC.text = '17:00';

      expect(controller.preflightError(), isNull);
    });
  });

  group('lampiran', () {
    setUp(() => useType(typeOf(id: 4)));

    test('berkas tanpa path tetap terkirim sebagai isi', () {
      // Berkas dari penyedia awan. Dulu ia tampil sebagai lampiran terpilih
      // dan diam-diam tidak ikut dikirim.
      controller.selectedFile.value = PlatformFile(
        name: 'surat.pdf',
        size: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final upload = controller.attachment();

      expect(upload, isNotNull);
      expect(upload!.filename, 'surat.pdf');
      expect(upload.bytes, isNotNull);
      expect(upload.sizeInBytes, 3);
    });

    test('berkas tanpa path maupun isi menghentikan pengiriman', () {
      controller.selectedFile.value = PlatformFile(name: 'x.pdf', size: 10);

      expect(controller.attachment(), isNull);
      expect(controller.preflightError(), contains('tidak bisa dibaca'));
    });

    test('melepas lampiran adalah tindakan tersendiri', () {
      controller.selectedFile.value = PlatformFile(
        name: 'surat.pdf',
        size: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      controller.clearFile();

      expect(controller.selectedFile.value, isNull);
    });

    test('hanya bentuk berkas yang diterima server yang ditawarkan', () {
      // `StorePermitRequest` menerima pdf, jpeg dan png saja, maksimal 5120 KB.
      expect(PermitCreateController.allowedExtensions, [
        'jpg',
        'jpeg',
        'png',
        'pdf',
      ]);
      expect(PermitCreateController.maxAttachmentBytes, 5120 * 1024);
    });
  });

  group('kebijakan tanggal', () {
    test('mengikuti jendela roster yang dijawab server', () async {
      when(
        () => repository.formData(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer(
        (_) async => PermitFormData(
          schedules: [
            Schedule.fromJson({'id': 8, 'work_day': '2026-09-02'}),
          ],
          from: DateTime(2026, 9, 2),
          to: DateTime(2026, 10, 2),
        ),
      );

      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.earliestDate, DateTime(2026, 9, 2));
      expect(controller.latestDate, DateTime(2026, 10, 2));
    });

    test('tanpa jawaban server memakai bawaan server: hari ini sampai +30', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(controller.earliestDate, today);
      expect(controller.latestDate, today.add(const Duration(days: 30)));
    });
  });

  group('memilih jadwal', () {
    test('mengisi kedua tanggal dengan hari kerjanya', () async {
      when(
        () => repository.formData(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer(
        (_) async => PermitFormData(
          schedules: [
            Schedule.fromJson({
              'id': 8,
              'work_day': '2026-09-02',
              'shift': 'Pagi',
              'in': '08:00:00',
              'out': '17:00:00',
            }),
          ],
        ),
      );

      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      // Jadwal pertama dipilihkan, dan tanggalnya ikut terisi — dulu hanya
      // dropdownnya yang terisi dan dua field wajib di bawahnya tetap kosong.
      expect(controller.selectedScheduleId.value, 8);
      expect(controller.startDateC.text, '2026-09-02');
      expect(controller.endDateC.text, '2026-09-02');
      expect(controller.isSingleDay, isTrue);
    });
  });

  group('memilih lampiran', () {
    PlatformFile chosen(String name, {int size = 1024, List<int>? bytes}) =>
        PlatformFile(
          name: name,
          size: size,
          bytes: bytes == null ? null : Uint8List.fromList(bytes),
          path: bytes == null ? '/tmp/$name' : null,
        );

    setUp(() => useType(typeOf(id: 4)));

    test(
      'membatalkan pemilih tidak membuang berkas yang sudah dipilih',
      () async {
        controller.selectedFile.value = chosen('lama.pdf', bytes: [1]);

        FilePicker.platform = _FakeFilePicker(null);
        await controller.pickFile();

        // Membatalkan berarti "tidak jadi memilih", bukan "hapus lampiran".
        expect(controller.selectedFile.value?.name, 'lama.pdf');
      },
    );

    test('berkas melebihi 5 MB ditolak sebelum diunggah', () async {
      controller.selectedFile.value = chosen('lama.pdf', bytes: [1]);

      final big = chosen('besar.pdf', size: 6 * 1024 * 1024, bytes: [1]);
      FilePicker.platform = _FakeFilePicker(FilePickerResult([big]));
      await controller.pickFile();

      expect(controller.selectedFile.value?.name, 'lama.pdf');
    });

    test('berkas dari penyedia awan diterima lewat isinya', () async {
      final cloud = chosen('awan.pdf', size: 3, bytes: [1, 2, 3]);
      FilePicker.platform = _FakeFilePicker(FilePickerResult([cloud]));
      await controller.pickFile();

      expect(controller.selectedFile.value?.name, 'awan.pdf');
      expect(controller.attachment()?.bytes, isNotNull);
    });

    test('berkas tanpa path maupun isi tidak pernah tampil terpilih', () async {
      FilePicker.platform = _FakeFilePicker(
        FilePickerResult([PlatformFile(name: 'hantu.pdf', size: 10)]),
      );
      await controller.pickFile();

      expect(controller.selectedFile.value, isNull);
    });

    test('mengganti berkas menggantikan yang sebelumnya', () async {
      controller.selectedFile.value = chosen('lama.pdf', bytes: [1]);

      FilePicker.platform = _FakeFilePicker(
        FilePickerResult([
          chosen('baru.pdf', size: 3, bytes: [1, 2, 3]),
        ]),
      );
      await controller.pickFile();

      expect(controller.selectedFile.value?.name, 'baru.pdf');
    });
  });
}
