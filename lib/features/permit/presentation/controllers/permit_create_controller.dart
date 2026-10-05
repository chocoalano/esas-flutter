import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../../../core/network/upload.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/leave_type.dart';
import '../../data/models/permit_variant.dart';
import '../../data/models/schedule.dart';
import '../../data/models/timework.dart';
import '../../data/repositories/permit_repository.dart';

/// The create-permit form.
///
/// The file this replaces opened with
/// `// ignore_for_file: use_build_context_synchronously` (MED-13), which hid
/// every use of a `BuildContext` after an `await` in a 275-line controller —
/// including new ones added later. The suppression is gone; the two pickers
/// that genuinely need a context now guard on `context.mounted`.
class PermitCreateController extends GetxController {
  PermitCreateController({required PermitRepository repository})
    : _repository = repository;

  final PermitRepository _repository;

  /// Berkas yang boleh dilampirkan, dan sebesar apa.
  ///
  /// Bukan pilihan tampilan: `StorePermitRequest` menerima
  /// `mimetypes:application/pdf,image/jpeg,image/png` dan `max:5120` kilobyte.
  /// Pemilih berkas dulu menawarkan `doc`, `docx` dan `xlsx` juga — tiga jenis
  /// yang pasti ditolak server setelah selesai diunggah.
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
  static const int maxAttachmentBytes = 5120 * 1024;

  final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final formKey = GlobalKey<FormState>();

  final timeinAdjustC = TextEditingController();
  final timeoutAdjustC = TextEditingController();
  final startDateC = TextEditingController();
  final endDateC = TextEditingController();
  final startTimeC = TextEditingController();
  final endTimeC = TextEditingController();
  final notesC = TextEditingController();

  final Rx<LeaveType> createType = LeaveType(
    id: 0,
    type: '',
    isPayed: false,
    approveLine: false,
    approveManager: false,
    approveHr: false,
    withFile: false,
    showMobile: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ).obs;

  final scheduleList = <Schedule>[].obs;
  final shiftList = <Timework>[].obs;

  final selectedScheduleId = RxnInt();
  final selectedPermitTypeId = RxnInt();
  final selectedCurrentShiftId = RxnInt();
  final selectedAdjustShiftId = RxnInt();
  final selectedFile = Rxn<PlatformFile>();

  /// Batas tanggal yang boleh diajukan, sebagaimana dijawab server.
  final Rxn<DateTime> rosterFrom = Rxn<DateTime>();
  final Rxn<DateTime> rosterTo = Rxn<DateTime>();

  /// Kunci idempoten milik satu percakapan "pengguna menekan Kirim", bukan satu
  /// panggilan HTTP. Lihat [IdempotencyKey]: yang dilindungi bukan ketukan
  /// ganda — tombolnya sudah dinonaktifkan — melainkan percobaan ulang setelah
  /// jawaban hilang di jalan. Kunci baru pada setiap percobaan membuat
  /// perlindungan itu tidak ada.
  String? _submissionKey;

  /// Formulir yang dibuka jenis izin ini.
  ///
  /// Dibaca dari jenisnya, bukan dari `permit_type_id`. Dulu dua angka — 15 dan
  /// 16 — yang memutuskannya, dan angka itu hanya benar pada satu basis data.
  /// Lihat [PermitVariant].
  PermitVariant get variant => createType.value.variant;

  bool get isTimeAdjustment => variant.isTimeAdjustment;
  bool get isShiftAdjustment => variant.isShiftAdjustment;

  /// Apakah izin ini mulai dan selesai pada hari yang sama.
  ///
  /// Menentukan boleh-tidaknya jam selesai lebih kecil dari jam mulai: pada
  /// izin sehari itu keliru, pada izin yang melewati tengah malam (shift
  /// malam) itu justru bentuk yang benar.
  bool get isSingleDay {
    final start = startDateC.text.trim();

    return start.isNotEmpty && start == endDateC.text.trim();
  }

  /// Hari paling awal yang boleh diajukan.
  ///
  /// Jendela roster milik server, bukan `DateTime(2000)`. Tanpa jawaban server
  /// dipakai bawaan yang sama dengan bawaannya: hari ini sampai 30 hari ke
  /// depan.
  DateTime get earliestDate => rosterFrom.value ?? _today;

  DateTime get latestDate =>
      rosterTo.value ?? _today.add(const Duration(days: 30));

  static DateTime get _today {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments;

    if (args is LeaveType) {
      createType.value = args;
      selectedPermitTypeId.value = args.id;
    }

    // Jenis izin dipilih di layar sebelumnya dan tidak bisa diganti dari sini,
    // jadi dalam praktiknya ini berjalan sekali. Ia tetap ada karena keadaan
    // formulir harus mengikuti variannya bila suatu hari jenisnya bisa
    // diganti — dan bukan payload yang menemukan sisa isian varian lama.
    ever(createType, (_) => _applyVariant());

    _loadForm();
  }

  @override
  void onClose() {
    // None of these were disposed before.
    for (final controller in [
      timeinAdjustC,
      timeoutAdjustC,
      startDateC,
      endDateC,
      startTimeC,
      endTimeC,
      notesC,
    ]) {
      controller.dispose();
    }

    super.onClose();
  }

  /// Membuang isian yang bukan milik varian yang sedang berlaku.
  ///
  /// Penyusunan payload sudah bersyarat, dan itulah batas terakhirnya; ini
  /// batas pertamanya. Sebuah field yang tidak terlihat tetapi masih terisi
  /// akan lolos dari mata pengguna, dan satu-satunya yang menghalanginya masuk
  /// ke pengajuan adalah satu `if` di tempat lain.
  void _applyVariant() {
    if (!isTimeAdjustment) {
      timeinAdjustC.clear();
      timeoutAdjustC.clear();
    }

    if (!isShiftAdjustment) {
      selectedCurrentShiftId.value = null;
      selectedAdjustShiftId.value = null;
    }
  }

  // ── Jam ───────────────────────────────────────────────────────────────────

  /// Jam dalam bentuk kanonik `HH:mm`, atau string kosong bila tidak terbaca.
  ///
  /// Satu tempat yang mengurus ini, dipakai oleh validator, oleh perbandingan
  /// antar-field dan oleh payload. Sebelumnya ada dua: validator membersihkan
  /// titik menjadi titik dua, `createPermit` membersihkannya untuk `start_time`
  /// dan `end_time` tetapi tidak untuk `timein_adjust`/`timeout_adjust` — jadi
  /// jenis izin penyesuaian jam mengirim `08.45` ke kolom yang divalidasi
  /// sebagai `date_format:H:i`.
  static String canonicalTime(String raw) {
    final minutes = minutesOfDay(raw);

    if (minutes == null) {
      return '';
    }

    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  /// Menit sejak tengah malam, atau null bila bukan jam yang sah.
  ///
  /// Membandingkan dua jam sebagai string adalah yang membuat "jam pulang harus
  /// setelah jam masuk" bisa dilewati: pemilih jam menulis `08.45` pada locale
  /// Indonesia, validator membersihkan satu sisi saja menjadi `08:30`, dan
  /// `':'` lebih besar daripada `'.'` — jadi 08:30 lolos sebagai "setelah"
  /// 08.45.
  static int? minutesOfDay(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .replaceAll('.', ':')
        .trim();

    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(cleaned);

    if (match == null) {
      return null;
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);

    if (hour > 23 || minute > 59) {
      return null;
    }

    return hour * 60 + minute;
  }

  // ── Muat & isian awal ─────────────────────────────────────────────────────

  void onScheduleChanged(int? newId) {
    selectedScheduleId.value = newId;

    final schedule = scheduleList.firstWhereOrNull((s) => s.id == newId);
    final workDate = schedule?.workDay;
    final formatted = workDate == null ? '' : dateFormatter.format(workDate);

    startDateC.text = formatted;
    endDateC.text = formatted;
  }

  Future<void> _loadForm() async {
    isLoading.value = true;

    try {
      // No type, company, department or employee. The server reads all of them
      // off the token, so a cached user missing one of them no longer means a
      // form that will not open.
      final form = await _repository.formData();

      scheduleList.assignAll(form.schedules);
      shiftList.assignAll(form.shifts);
      rosterFrom.value = form.from;
      rosterTo.value = form.to;

      if (scheduleList.isNotEmpty) {
        // Lewat `onScheduleChanged`, bukan dengan menyetel id begitu saja:
        // memilih jadwal itulah yang mengisi tanggal mulai dan selesai. Versi
        // sebelumnya memilihkan jadwal pertama tanpa mengisi tanggalnya, jadi
        // formulir terbuka dengan dua field wajib yang kosong padahal
        // dropdown di atasnya sudah terisi.
        onScheduleChanged(scheduleList.first.id);
      }

      // Kedua dropdown shift sengaja dibiarkan kosong. Mengisinya dengan shift
      // pertama membuat setiap pengajuan — sakit, cuti tahunan, apa pun —
      // terkirim membawa `current_shift_id` dan `adjust_shift_id`, dan pada
      // jenis penyesuaian shift keduanya bernilai sama: permintaan tukar shift
      // yang tidak menukar apa-apa, yang kini juga ditolak server dengan
      // `permit_shift_unchanged`.
    } on ApiException catch (error) {
      showErrorSnackbar('Gagal memuat data awal: ${error.message}');
    } catch (error, stackTrace) {
      // Bukan hanya ApiException: satu baris jadwal yang tidak bisa diurai
      // dulunya melewati `catch` ini dan meninggalkan formulir dengan dropdown
      // kosong tanpa satu pun keterangan.
      AppLogger.error(
        'Data awal formulir izin tidak bisa dibaca',
        error: error,
        stackTrace: stackTrace,
      );
      showErrorSnackbar('Data awal formulir tidak bisa dibaca.');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Kirim ─────────────────────────────────────────────────────────────────

  /// Isi pengajuan, disusun dari bagian bersama ditambah bagian variannya.
  ///
  /// Terpisah dari [createPermit] supaya bisa diperiksa apa adanya oleh tes:
  /// pertanyaan "apakah cuti tahunan membawa id shift" tidak seharusnya hanya
  /// bisa dijawab dengan menjalankan seluruh layar.
  Map<String, dynamic> buildFields() {
    return {
      // No `permit_numbers`. It used to be fetched into a read-only field and
      // posted back; the server mints it, because a reference somebody quotes
      // on a form is the application's job to issue - two requests could
      // otherwise share one and a typo was silent.
      'user_timework_schedule_id': selectedScheduleId.value,
      'permit_type_id': selectedPermitTypeId.value,
      'start_date': startDateC.text,
      'end_date': endDateC.text,
      'start_time': canonicalTime(startTimeC.text),
      'end_time': canonicalTime(endTimeC.text),
      'notes': notesC.text,

      // Empat field di bawah ini hanya milik variannya masing-masing.
      // Sebelumnya keempatnya ikut pada setiap pengajuan: dua jam penyesuaian
      // sebagai string kosong, dua id shift berisi shift pertama yang
      // dipilihkan sendiri oleh formulir.
      if (isTimeAdjustment) ...{
        // `timein_adjust`, not `time_in_adjust`. The column has never had the
        // second underscore, and the old backend was lenient about it.
        'timein_adjust': canonicalTime(timeinAdjustC.text),
        'timeout_adjust': canonicalTime(timeoutAdjustC.text),
      },
      if (isShiftAdjustment) ...{
        'current_shift_id': selectedCurrentShiftId.value,
        'adjust_shift_id': selectedAdjustShiftId.value,
      },
    };
  }

  Future<void> createPermit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      showWarningSnackbar('Periksa kembali formulir.');
      return;
    }

    final String? blocker = preflightError();

    if (blocker != null) {
      showWarningSnackbar(blocker);
      return;
    }

    isSubmitting.value = true;

    // Kunci bertahan melintasi percobaan ulang; hanya dilepas bila permintaan
    // benar-benar sampai dan dijawab.
    _submissionKey ??= IdempotencyKey.mint();

    try {
      final created = await _repository.create(
        fields: buildFields(),
        attachment: attachment(),
        idempotencyKey: _submissionKey,
      );

      if (!created) {
        showErrorSnackbar('Pengajuan tidak dapat dikirim.');
        return;
      }

      _submissionKey = null;
      showSuccessSnackbar('Permohonan izin berhasil dibuat!');
      Get.offAllNamed(PermitRoutes.list, arguments: createType.value);
    } on ApiException catch (error) {
      // Server menolak dengan sadar (4xx): permintaan tidak tercatat, dan yang
      // dikirim berikutnya adalah pengajuan lain. Kegagalan transport atau 5xx
      // justru sebaliknya — ia mungkin sudah tercatat, jadi kuncinya dipegang.
      final int? status = error.status;

      if (status != null && status >= 400 && status < 500) {
        _submissionKey = null;
      }

      showErrorSnackbar(error.firstFieldError ?? error.message);
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Yang tidak bisa diperiksa oleh validator satu field.
  String? preflightError() {
    if (selectedPermitTypeId.value == null || createType.value.id <= 0) {
      return 'Jenis izin tidak dikenali. Buka kembali dari daftar jenis '
          'perizinan.';
    }

    final file = selectedFile.value;

    if (createType.value.withFile && file == null) {
      return 'Jenis izin ini wajib melampirkan dokumen.';
    }

    if (file != null && attachment() == null) {
      return 'Berkas yang dipilih tidak bisa dibaca. Pilih ulang berkasnya.';
    }

    if (isTimeAdjustment &&
        timeinAdjustC.text.trim().isEmpty &&
        timeoutAdjustC.text.trim().isEmpty) {
      return 'Isi minimal satu jam penyesuaian.';
    }

    return null;
  }

  // ── Lampiran ──────────────────────────────────────────────────────────────

  /// Lampiran sebagaimana akan dikirim, atau null bila tidak ada yang bisa
  /// dikirim.
  ///
  /// Berkas dari penyedia awan sampai tanpa path lokal. Versi sebelumnya
  /// membangun permintaan dari path saja, jadi layar menampilkan lampiran,
  /// permintaan berangkat tanpanya, dan orang yang disuruh membawa surat dokter
  /// baru tahu berhari-hari kemudian bahwa ia tidak membawanya.
  Upload? attachment() {
    final file = selectedFile.value;

    if (file == null) {
      return null;
    }

    final bytes = file.bytes;

    if (bytes != null) {
      return Upload.bytes(bytes, filename: file.name);
    }

    final path = file.path;

    if (path == null) {
      AppLogger.warning(
        'Lampiran terpilih tidak punya path maupun isi; berkas tidak dapat '
        'diunggah.',
      );
      return null;
    }

    return Upload.file(File(path), filename: file.name);
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      // Supaya berkas dari penyedia yang tidak menyimpan salinan lokal tetap
      // punya isi untuk dikirim. Ukurannya dibatasi tepat di bawah ini, jadi
      // yang dibaca ke memori tidak pernah lebih besar dari yang diterima
      // server.
      withData: true,
    );

    // Membatalkan pemilih berarti membatalkan pemilihan, bukan membuang berkas
    // yang sudah dipilih sebelumnya — itu yang terjadi ketika hasil null
    // langsung ditulis ke `selectedFile`.
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;

    if (file.size > maxAttachmentBytes) {
      showWarningSnackbar(
        'Berkas melebihi 5 MB. Kecilkan dulu atau pilih berkas lain.',
      );
      return;
    }

    if (file.bytes == null && file.path == null) {
      showWarningSnackbar(
        'Berkas itu tidak bisa dibaca dari lokasinya. Unduh dulu ke '
        'perangkat, lalu pilih kembali.',
      );
      return;
    }

    selectedFile.value = file;
  }

  void clearFile() => selectedFile.value = null;

  // ── Pemilih tanggal & jam ─────────────────────────────────────────────────

  Future<void> pickDate(BuildContext context, TextEditingController c) async {
    final DateTime first = earliestDate;
    final DateTime last = latestDate.isBefore(first) ? first : latestDate;
    final DateTime current = DateTime.tryParse(c.text) ?? first;

    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first)
          ? first
          : (current.isAfter(last) ? last : current),
      // Rentangnya milik roster yang dijawab server, bukan 2000–2101 yang
      // menawarkan tanggal yang pasti ditolak `permit_no_schedule`.
      firstDate: first,
      lastDate: last,
      locale: const Locale('id', 'ID'),
    );

    if (picked != null) {
      c.text = dateFormatter.format(picked);
    }
  }

  Future<void> pickTime(BuildContext context, TextEditingController c) async {
    // `split(':')` atas isi field tidak pernah mengembalikan dua bagian:
    // pemilih menuliskannya dengan titik, jadi jam yang sudah dipilih selalu
    // hilang dan pemilih terbuka pada jam sekarang.
    final minutes = minutesOfDay(c.text);
    final initialTime = minutes == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked == null) {
      return;
    }

    // Ditulis sebagai `HH:mm`, bukan lewat `TimeOfDay.format`. Yang terakhir
    // memakai MediaQuery dari `context` di luar pemilih — bukan yang dipaksa
    // 24 jam di atas — dan pada locale Indonesia mengembalikan `08.30`. Titik
    // itulah yang lolos ke payload dan merusak perbandingan antar-field,
    // padahal petunjuk di field ini sendiri berbunyi "HH:mm".
    c.text =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
  }
}
