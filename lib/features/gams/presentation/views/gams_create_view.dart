import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../../../../core/ui/components/app_section_header.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../controllers/gams_create_controller.dart';
import '../controllers/gams_dashboard_controller.dart';
import '../routes/gams_routes.dart';
import '../widgets/gams_service_fields.dart';

/// The four GAMS requests, one form each (GAMS-01).
class GamsCreateView extends GetView<GamsCreateController> {
  const GamsCreateView({super.key, required this.kind});

  final GamsCreateKind kind;

  @override
  String? get tag => kind.name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(kind.title),
        actions: [
          IconButton(
            tooltip: 'Riwayat GAMS',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _toDashboard(context),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // The options did not load: say so and offer a retry, rather than a
        // form with an empty dropdown (UX-A07).
        if (controller.loadError.value case final failed?) {
          return AppErrorState(
            title: failed.isForbidden
                ? 'Tidak ada akses'
                : 'Pilihan formulir belum dapat dimuat',
            message: failed.message,
            onRetry: failed.isForbidden ? null : controller.loadOptions,
          );
        }

        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.md,
          ),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSectionHeader(
                    title: 'Formulir ${kind.title}',
                    subtitle: 'Lengkapi data permohonan berikut ini',
                    dense: true,
                    naturalCase: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._fields(context, theme),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (controller.error.value case final message?)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.danger.foreground,
                  ),
                ),
              ),
            AppButton(
              label: 'Kirim',
              icon: Icons.send_rounded,
              busy: controller.isSubmitting.value,
              onPressed: controller.isSubmitting.value
                  ? null
                  : () => _submit(context),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final sent = await controller.submit();
    if (!sent) return;

    showSuccessSnackbar('${kind.title} terkirim.');
    // The dashboard lists what was just filed.
    if (context.mounted) _toDashboard(context, filed: true);
  }

  /// Back to the dashboard this form was opened from, or to a new one when it
  /// was opened from elsewhere (UAT review H2).
  ///
  /// `Get.offNamed` stacked a second dashboard over the first. The second
  /// reused the first one's controller — registered and not dirty, so no
  /// `onInit` — and never reloaded: the request just filed was missing, and
  /// Back led to another copy of the same page. A dashboard under this form is
  /// one whose route-scoped controller is still alive.
  void _toDashboard(BuildContext context, {bool filed = false}) {
    if (Get.isRegistered<GamsDashboardController>()) {
      Navigator.of(context).pop(filed);
    } else {
      Get.offNamed(GamsRoutes.gams);
    }
  }

  List<Widget> _fields(BuildContext context, ThemeData theme) {
    const gap = SizedBox(height: AppSpacing.sm);

    Widget dropdown<T>({
      required String label,
      required List<(int, String)> items,
      required RxnInt value,
      String? helperText,
    }) => DropdownButtonFormField<int>(
      initialValue: value.value,
      isExpanded: true,
      decoration: appInputDecoration(theme, label, helperText: helperText),
      items: [
        for (final (id, name) in items)
          DropdownMenuItem(value: id, child: Text(name)),
      ],
      onChanged: (id) => value.value = id,
    );

    Widget text(
      TextEditingController c,
      String label, {
      int lines = 1,
      TextInputType? type,
      String? helperText,
    }) => TextField(
      controller: c,
      minLines: lines,
      maxLines: lines,
      keyboardType: type,
      decoration: appInputDecoration(theme, label, helperText: helperText),
    );

    final period = [
      gap,
      _DateTimeField(
        label: 'Mulai',
        value: controller.startAt,
        helperText: 'Tentukan tanggal dan jam awal penggunaan.',
      ),
      gap,
      _DateTimeField(
        label: 'Selesai',
        value: controller.endAt,
        helperText: 'Tentukan tanggal dan jam berakhirnya penggunaan.',
      ),
    ];

    return switch (kind) {
      GamsCreateKind.serviceRequest => [
        dropdown(
          label: 'Layanan',
          items: [for (final d in controller.definitions) (d.id, d.title)],
          value: controller.optionId,
          helperText: controller.definitions.isEmpty
              ? 'Belum ada layanan GA yang dapat Anda ajukan. Hubungi bagian GA.'
              : 'Pilih jenis fasilitas atau layanan umum yang dibutuhkan.',
        ),
        gap,
        dropdown(
          label: controller.selectedDefinition?.requiresFacility == true
              ? 'Gedung'
              : 'Gedung (opsional)',
          items: [for (final f in controller.facilities) (f.id, f.name)],
          value: controller.facilityId,
          helperText: 'Pilih lokasi gedung kerja terkait permintaan ini.',
        ),
        gap,
        text(
          controller.subjectC,
          'Judul permintaan',
          helperText: 'Tulis ringkasan permohonan layanan umum secara singkat.',
        ),
        gap,
        text(
          controller.descriptionC,
          controller.selectedDefinition?.requiresDescription == true
              ? 'Keterangan'
              : 'Keterangan (opsional)',
          lines: 3,
          helperText:
              'Jelaskan rincian kebutuhan, jumlah barang, atau catatan spesifik.',
        ),
        // The chosen service's own fields (FUNC-A01).
        GamsServiceFields(controller: controller),
        gap,
        DropdownButtonFormField<String>(
          initialValue: controller.priority.value,
          decoration: appInputDecoration(
            theme,
            'Prioritas',
            helperText: 'Tentukan tingkat urgensi penanganan permohonan ini.',
          ),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Rendah')),
            DropdownMenuItem(value: 'medium', child: Text('Sedang')),
            DropdownMenuItem(value: 'high', child: Text('Tinggi')),
            DropdownMenuItem(value: 'urgent', child: Text('Mendesak')),
          ],
          onChanged: (p) => controller.priority.value = p ?? 'medium',
        ),
      ],
      GamsCreateKind.spaceReservation => [
        dropdown(
          label: 'Ruang',
          items: [for (final s in controller.spaces) (s.id, s.name)],
          value: controller.optionId,
          helperText:
              'Pilih ruangan rapat atau fasilitas bersama yang ingin digunakan.',
        ),
        ...period,
      ],
      GamsCreateKind.vehicleBooking => [
        dropdown(
          label: 'Kendaraan',
          items: [
            for (final v in controller.vehicles)
              (v.id, '${v.name} · ${v.number}'),
          ],
          value: controller.optionId,
          helperText:
              'Pilih armada kendaraan operasional kantor yang tersedia.',
        ),
        gap,
        text(
          controller.subjectC,
          'Keperluan',
          helperText:
              'Jelaskan tujuan dinas, rute perjalanan, dan estimasi penumpang.',
        ),
        ...period,
      ],
      GamsCreateKind.visit => [
        dropdown(
          label: 'Gedung',
          items: [for (final f in controller.facilities) (f.id, f.name)],
          value: controller.facilityId,
          helperText: 'Pilih lokasi gedung tempat penerimaan kunjungan tamu.',
        ),
        gap,
        text(
          controller.visitorNameC,
          'Nama tamu',
          helperText: 'Masukkan nama lengkap tamu atau perwakilan pihak luar.',
        ),
        gap,
        text(
          controller.visitorPhoneC,
          'Telepon tamu (opsional)',
          type: TextInputType.phone,
          helperText: 'Nomor telepon atau kontak WhatsApp aktif tamu.',
        ),
        gap,
        text(
          controller.visitorCompanyC,
          'Perusahaan tamu (opsional)',
          helperText: 'Nama instansi, vendor, atau organisasi asal tamu.',
        ),
        gap,
        text(
          controller.subjectC,
          'Keperluan kunjungan',
          helperText:
              'Jelaskan agenda pertemuan atau kepentingan kunjungan tamu.',
        ),
      ],
    };
  }
}

/// A date and a time, picked one after the other.
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    this.helperText,
  });

  final String label;
  final Rxn<DateTime> value;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final current = value.value;

      return InkWell(
        onTap: () => _pick(context),
        child: InputDecorator(
          decoration: appInputDecoration(
            theme,
            label,
            helperText: helperText,
            suffixIcon: const Icon(Icons.event_rounded, size: 18),
          ),
          child: Text(
            current == null
                ? 'Pilih tanggal & jam'
                : DateFormat('EEE, d MMM yyyy · HH:mm', 'id').format(current),
          ),
        ),
      );
    });
  }

  Future<void> _pick(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value.value ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value.value ?? now),
    );
    if (time == null) return;

    value.value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }
}
