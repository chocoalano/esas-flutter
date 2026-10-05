import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_button.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_input_decoration.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/permit_create_controller.dart';

/// Formulir pengajuan izin.
///
/// Tata letaknya berubah dari satu kolom panjang berisi belasan field sejajar
/// menjadi tiga bagian bernama — jadwal, waktu, keterangan — sehingga panjang
/// formulir terbaca sebagai tiga langkah pendek dan bukan satu daftar tanpa
/// ujung.
///
/// Label pindah ke atas kotak isian. Label mengambang bawaan Material bergerak
/// dan mengecil saat field mendapat fokus; pada formulir sepanjang ini,
/// belasan label yang bergeser-geser membuat kolom terasa gelisah. Teks
/// penjelas tetap ada di bawah setiap field — isinya berharga dan itulah yang
/// menjadikan formulir ini informatif — hanya kini dicetak dengan warna redup
/// supaya tidak bersaing dengan apa yang diketik pengguna.
///
/// Tombol simpan pindah ke bilah tetap di kaki layar, jadi ia tidak perlu
/// dicari dengan menggulir sampai dasar.
class PermitCreateView extends GetView<PermitCreateController> {
  const PermitCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void back() => Get.offAllNamed(
      PermitRoutes.list,
      arguments: controller.createType.value,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Kembali',
            onPressed: back,
          ),
          titleSpacing: 0,
          title: Obx(
            () => Text(
              controller.createType.value.type,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        body: SafeArea(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Padding(
                padding: EdgeInsets.only(top: AppSpacing.lg),
                child: AppSkeletonList(count: 4),
              );
            }
            return _buildForm(context, theme);
          }),
        ),
        bottomNavigationBar: _SubmitBar(controller: controller),
      ),
    );
  }

  Widget _buildForm(BuildContext context, ThemeData theme) {
    final bool isTimeAdjustment = controller.isTimeAdjustment;
    final bool isShiftAdjustment = controller.isShiftAdjustment;
    final bool needsFile = controller.createType.value.withFile;

    return Form(
      key: controller.formKey,
      // Sebuah kolom di dalam penggulir, bukan `ListView`. Bedanya bukan gaya:
      // `ListView` melepas field yang tergulir keluar layar, dan field yang
      // lepas ikut lepas dari `Form` — `validate()` melewatinya begitu saja.
      // Dengan tombol kirim yang menetap di kaki layar, orang bisa menekannya
      // tanpa pernah menggulir ke bawah, dan "Jam mulai wajib diisi" tidak
      // pernah sempat berbunyi.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.xl,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(title: 'Jadwal kerja'),
            _Field(
              label: 'Jadwal kerja',
              required: true,
              description: controller.scheduleList.isEmpty
                  ? 'Tidak ada jadwal kerja yang bisa dipakai. Hubungi HR '
                        'sebelum mengajukan.'
                  : 'Pilih jadwal kerja yang menjadi acuan pengajuan ini. '
                        'Tanggal di bawah mengikuti pilihan ini.',
              child: _buildDropdownSchedule(theme),
            ),

            if (isShiftAdjustment) ...[
              const SizedBox(height: AppSpacing.lg),
              const AppSectionHeader(title: 'Penyesuaian shift'),
              _Field(
                label: 'Shift saat ini',
                required: true,
                description: 'Shift yang berlaku sebelum penyesuaian.',
                child: _buildDropdownShift(
                  theme,
                  'Shift Saat Ini',
                  controller.selectedCurrentShiftId,
                  validator: (v) =>
                      v == null ? 'Shift saat ini wajib diisi' : null,
                ),
              ),
              _Field(
                label: 'Shift penyesuaian',
                required: true,
                description: 'Shift yang diminta setelah penyesuaian.',
                child: _buildDropdownShift(
                  theme,
                  'Shift Penyesuaian',
                  controller.selectedAdjustShiftId,
                  validator: (v) {
                    if (v == null) return 'Shift penyesuaian wajib diisi';
                    // Tukar shift dengan shift yang sama bukan pengajuan; dulu
                    // justru itu yang terkirim, karena formulir memilihkan
                    // shift pertama untuk kedua dropdown.
                    if (v == controller.selectedCurrentShiftId.value) {
                      return 'Pilih shift yang berbeda dari shift saat ini';
                    }
                    return null;
                  },
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader(title: 'Waktu'),

            if (isTimeAdjustment) ...[
              _Field(
                label: 'Jam masuk penyesuaian',
                description:
                    'Format 24 jam, misalnya 08:30. Jam ini menjadi acuan '
                    'penyesuaian data absensi masuk. Isi minimal salah satu '
                    'dari dua jam penyesuaian.',
                child: _buildTimePickerField(
                  context,
                  theme,
                  'Jam Masuk Penyesuaian',
                  controller.timeinAdjustC,
                ),
              ),
              _Field(
                label: 'Jam pulang penyesuaian',
                description:
                    'Format 24 jam, misalnya 17:00. Harus setelah jam masuk '
                    'penyesuaian.',
                child: _buildTimePickerField(
                  context,
                  theme,
                  'Jam Pulang Penyesuaian',
                  controller.timeoutAdjustC,
                  validateAfter: controller.timeinAdjustC,
                ),
              ),
            ],

            if (controller.selectedScheduleId.value != null) ...[
              _Field(
                label: 'Tanggal mulai',
                required: true,
                description: 'Hari pertama izin ini berlaku.',
                child: _buildDatePickerField(
                  context,
                  theme,
                  'Tanggal Mulai',
                  controller.startDateC,
                ),
              ),
              _Field(
                label: 'Tanggal selesai',
                required: true,
                description:
                    'Hari terakhir izin ini berlaku. Untuk izin sehari, '
                    'sama dengan tanggal mulai.',
                child: _buildDatePickerField(
                  context,
                  theme,
                  'Tanggal Selesai',
                  controller.endDateC,
                  notBeforeDate: controller.startDateC,
                ),
              ),
            ],

            _Field(
              label: 'Jam mulai',
              required: true,
              description: 'Format 24 jam, misalnya 08:30.',
              child: _buildTimePickerField(
                context,
                theme,
                'Jam Mulai',
                controller.startTimeC,
                isRequired: true,
              ),
            ),
            _Field(
              label: 'Jam selesai',
              required: true,
              description: 'Format 24 jam, misalnya 17:00.',
              child: _buildTimePickerField(
                context,
                theme,
                'Jam Selesai',
                controller.endTimeC,
                isRequired: true,
                validateAfter: controller.startTimeC,
                // Hanya untuk izin sehari. Izin yang melewati tengah malam sah
                // berakhir pada jam yang lebih kecil daripada jam mulainya.
                sameDayOnly: true,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader(title: 'Keterangan'),
            _Field(
              label: 'Catatan',
              description:
                  'Opsional. Jelaskan alasan pengajuan agar penyetuju tidak '
                  'perlu bertanya ulang.',
              child: _buildTextFormField(
                controller.notesC,
                theme,
                'Catatan',
                maxLines: 4,
                // Sepanjang yang diterima `StorePermitRequest`. Batas 255 yang
                // lama memotong catatan yang sebenarnya sah.
                maxLength: 2000,
              ),
            ),
            _Field(
              label: 'Lampiran',
              // Daftar jenis izin sudah memasang lencana "Perlu lampiran" untuk
              // jenis ini; formulirnya dulu tetap menyebut lampiran opsional
              // dan membiarkan pengajuan berangkat tanpa berkas, untuk ditolak
              // server.
              required: needsFile,
              description: needsFile
                  ? 'Wajib untuk jenis izin ini. JPG, PNG atau PDF, '
                        'maksimal 5 MB.'
                  : 'Opsional. JPG, PNG atau PDF, maksimal 5 MB.',
              child: _FilePicker(controller: controller),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Field builders.
  // ---------------------------------------------------------------------

  Widget _buildDropdownSchedule(ThemeData theme) => Obx(
    () => DropdownButtonFormField<int>(
      initialValue: controller.selectedScheduleId.value,
      decoration: appInputDecoration(theme, ''),
      isExpanded: true,
      hint: const Text('Pilih jadwal kerja'),
      items: controller.scheduleList
          .map(
            (item) => DropdownMenuItem<int>(
              value: item.id,
              child: Text(
                // Tanggal, shift, dan penanda "sudah absen" — server mengirim
                // ketiganya justru supaya bisa dibaca sebelum memilih.
                item.optionLabel,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: controller.onScheduleChanged,
      validator: (v) => v == null ? 'Jadwal kerja wajib diisi' : null,
    ),
  );

  Widget _buildDropdownShift(
    ThemeData theme,
    String label,
    Rx<int?> selectedValue, {
    String? Function(int?)? validator,
  }) => DropdownButtonFormField<int>(
    initialValue: selectedValue.value,
    decoration: appInputDecoration(theme, ''),
    isExpanded: true,
    hint: Text('Pilih $label'.toLowerCase()),
    items: controller.shiftList
        .map(
          (item) => DropdownMenuItem<int>(
            value: item.id,
            child: Text(item.name ?? 'Jam kerja tidak diketahui'),
          ),
        )
        .toList(),
    onChanged: (v) => selectedValue.value = v,
    validator: validator,
  );

  Widget _buildTextFormField(
    TextEditingController ctrl,
    ThemeData theme,
    String label, {
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: appInputDecoration(theme, '').copyWith(
        hintText: label,
        // Penghitung karakter disembunyikan: ia menambah satu baris di bawah
        // setiap field padahal batasnya sudah dipaksakan oleh `maxLength`.
        counterText: '',
      ),
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      readOnly: readOnly,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildDatePickerField(
    BuildContext context,
    ThemeData theme,
    String label,
    TextEditingController controller, {
    TextEditingController? notBeforeDate,
  }) => TextFormField(
    controller: controller,
    readOnly: true,
    onTap: () async => await this.controller.pickDate(context, controller),
    decoration: appInputDecoration(theme, '').copyWith(
      hintText: 'YYYY-MM-DD',
      suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
    ),
    validator: (val) {
      final value = val?.trim();
      if (value == null || value.isEmpty) return '$label wajib diisi';

      // Validasi format dasar YYYY-MM-DD (opsional, sebelum parse)
      final basic = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (!basic.hasMatch(value)) {
        return 'Format tanggal tidak valid (YYYY-MM-DD)';
      }

      final date = DateTime.tryParse(value);
      if (date == null) return 'Format tanggal tidak valid';

      // Di luar jendela roster, server menolak dengan `permit_no_schedule`.
      // Pemilih tanggal sudah dibatasi ke jendela itu, tetapi isian field bisa
      // datang dari tempat lain — state yang dipulihkan, tautan dalam — dan
      // penolakan yang bisa dijelaskan di sini lebih baik daripada penolakan
      // yang datang setelah formulir dikirim.
      final DateTime first = this.controller.earliestDate;
      final DateTime last = this.controller.latestDate;

      if (date.isBefore(first) || date.isAfter(last)) {
        final format = this.controller.dateFormatter;

        return 'Di luar jadwal kerja Anda '
            '(${format.format(first)} s.d. ${format.format(last)})';
      }

      // Tanggal selesai boleh sama dengan tanggal mulai — izin sehari adalah
      // bentuk yang paling sering diajukan. Aturan lama menuntut "setelah",
      // padahal memilih jadwal mengisi kedua tanggal dengan hari yang sama:
      // formulir terbuka dalam keadaan yang tidak mungkin dikirim.
      final beforeRaw = notBeforeDate?.text.trim();
      if (beforeRaw != null &&
          beforeRaw.isNotEmpty &&
          basic.hasMatch(beforeRaw)) {
        final startDate = DateTime.tryParse(beforeRaw);
        if (startDate != null && date.isBefore(startDate)) {
          return 'Tidak boleh sebelum tanggal mulai';
        }
      }
      return null;
    },
  );

  Widget _buildTimePickerField(
    BuildContext context,
    ThemeData theme,
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    TextEditingController? validateAfter,
    bool sameDayOnly = false,
  }) => TextFormField(
    controller: controller,
    readOnly: true,
    onTap: () => this.controller.pickTime(context, controller),
    decoration: appInputDecoration(theme, '').copyWith(
      hintText: 'HH:mm',
      suffixIcon: const Icon(Icons.access_time_rounded, size: 18),
    ),
    validator: (val) {
      final raw = val?.trim() ?? '';

      if (raw.isEmpty) {
        return isRequired ? '$label wajib diisi' : null;
      }

      // Dibandingkan sebagai menit, bukan sebagai teks. `compareTo` atas dua
      // string jam memberi jawaban yang salah begitu kedua sisi memakai
      // pemisah yang berbeda, dan itulah keadaan normalnya di sini.
      final int? minutes = PermitCreateController.minutesOfDay(raw);
      if (minutes == null) {
        return 'Format jam tidak valid (HH:mm)';
      }

      final String otherRaw = validateAfter?.text.trim() ?? '';
      final int? other = otherRaw.isEmpty
          ? null
          : PermitCreateController.minutesOfDay(otherRaw);

      if (other != null &&
          (!sameDayOnly || this.controller.isSingleDay) &&
          minutes <= other) {
        return 'Harus setelah ${PermitCreateController.canonicalTime(otherRaw)}';
      }
      return null;
    },
  );
}

/// Satu field beserta label di atasnya dan teks penjelas di bawahnya.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.child,
    this.description,
    this.required = false,
  });

  final String label;
  final Widget child;
  final String? description;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppFieldLabel(label, required: required),
          child,
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm - 2),
            Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.palette.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pemilih berkas: satu kartu yang menunjukkan keadaannya sendiri.
///
/// Sebelumnya berupa teks "Belum pilih file" di sebelah tombol berwarna
/// sekunder. Setelah berkas dipilih, satu-satunya perubahan adalah teks itu
/// berganti nama berkas — dan tidak ada cara untuk membatalkannya.
class _FilePicker extends StatelessWidget {
  const _FilePicker({required this.controller});

  final PermitCreateController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Obx(() {
      final file = controller.selectedFile.value;

      if (file == null) {
        return AppCard(
          onTap: controller.pickFile,
          color: palette.surfaceSubtle,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Icon(
                Icons.upload_file_outlined,
                size: 18,
                color: palette.textMuted,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Pilih berkas',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            const AppIconBox(icon: Icons.description_outlined, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                file.name,
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Ganti berkas',
              onPressed: controller.pickFile,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            ),
            // Melepas lampiran yang terlanjur dipilih. Sebelumnya satu-satunya
            // cara adalah membatalkan pemilih berkas, yang memang menghapusnya
            // — tetapi sebagai efek samping, bukan sebagai pilihan.
            IconButton(
              tooltip: 'Hapus lampiran',
              onPressed: controller.clearFile,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      );
    });
  }
}

/// Bilah simpan di kaki layar, beserta laporan hasil validasinya.
///
/// Sebelumnya kegagalan validasi dijawab sebuah toast di TEPI ATAS layar —
/// sekitar 200px di atas ibu jari yang baru saja menekan tombolnya — yang
/// berbunyi "Periksa kembali formulir." dan tidak menyebutkan berapa isian
/// yang salah maupun di mana. Pada formulir sepanjang ini, "periksa kembali"
/// berarti menggulir seluruh formulir dari awal.
///
/// Sekarang jumlahnya dilaporkan di baris tepat di atas tombol yang ditekan,
/// dan layar menggulir sendiri ke field pertama yang bermasalah.
class _SubmitBar extends StatefulWidget {
  const _SubmitBar({required this.controller});

  final PermitCreateController controller;

  @override
  State<_SubmitBar> createState() => _SubmitBarState();
}

class _SubmitBarState extends State<_SubmitBar> {
  /// Berapa field yang gagal divalidasi pada percobaan terakhir. Nol berarti
  /// belum pernah gagal, atau kegagalan yang lalu sudah dibereskan.
  int _errorCount = 0;

  void _submit() {
    final FormState? form = widget.controller.formKey.currentState;

    // `validate()` dipanggil di sini supaya jumlah dan urutan field yang salah
    // bisa dibaca dari pohon yang sama. `createPermit()` memvalidasi ulang —
    // validator di sini tidak punya efek samping, jadi menjalankannya dua kali
    // memberi jawaban yang sama.
    if (form?.validate() ?? false) {
      if (_errorCount != 0) setState(() => _errorCount = 0);
      widget.controller.createPermit();
      return;
    }

    final List<FormFieldState<dynamic>> errored = _erroredFields(form);

    setState(() => _errorCount = errored.length);

    if (errored.isEmpty) return;

    // Field pertama dalam urutan pohon adalah field teratas dalam urutan
    // layar: formulir ini satu kolom di dalam satu penggulir.
    Scrollable.ensureVisible(
      errored.first.context,
      alignment: 0.1,
      duration: AppDurations.normal,
      curve: AppMotion.standard,
    );
  }

  /// Field yang sedang membawa pesan galat, dalam urutan gambar.
  ///
  /// `FormState` tidak mengekspos field-fieldnya, jadi pohonnya yang ditelusuri.
  /// Hasilnya urut sesuai urutan anak — yang di formulir ini sama dengan urutan
  /// dari atas ke bawah.
  static List<FormFieldState<dynamic>> _erroredFields(FormState? form) {
    final BuildContext? formContext = form?.context;

    if (formContext == null) return const [];

    final List<FormFieldState<dynamic>> found = <FormFieldState<dynamic>>[];

    void visitor(Element element) {
      if (element is StatefulElement) {
        final State<StatefulWidget> state = element.state;
        if (state is FormFieldState<dynamic> && state.hasError) {
          found.add(state);
        }
      }
      element.visitChildren(visitor);
    }

    formContext.visitChildElements(visitor);

    return found;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorCount > 0) ...[
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: AppIconSizes.md,
                        color: palette.danger.foreground,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '$_errorCount isian perlu diperbaiki',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.danger.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Obx(
                () => AppButton(
                  label: 'Kirim pengajuan',
                  busy: widget.controller.isSubmitting.value,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
