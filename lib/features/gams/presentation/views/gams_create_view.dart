import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../controllers/gams_create_controller.dart';
import '../controllers/gams_dashboard_controller.dart';
import '../routes/gams_routes.dart';

/// The four GAMS requests, one form each (GAMS-01).
class GamsCreateView extends GetView<GamsCreateController> {
  const GamsCreateView({super.key, required this.kind});

  final GamsCreateKind kind;

  @override
  String? get tag => kind.name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            ..._fields(context, theme),
            const SizedBox(height: AppSpacing.md),
            if (controller.error.value case final message?)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.palette.danger.foreground,
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
    const gap = SizedBox(height: AppSpacing.md);

    Widget dropdown<T>({
      required String label,
      required List<(int, String)> items,
      required RxnInt value,
    }) => DropdownButtonFormField<int>(
      initialValue: value.value,
      isExpanded: true,
      decoration: appInputDecoration(theme, label),
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
    }) => TextField(
      controller: c,
      minLines: lines,
      maxLines: lines,
      keyboardType: type,
      decoration: appInputDecoration(theme, label),
    );

    final period = [
      gap,
      _DateTimeField(label: 'Mulai', value: controller.startAt),
      gap,
      _DateTimeField(label: 'Selesai', value: controller.endAt),
    ];

    return switch (kind) {
      GamsCreateKind.serviceRequest => [
        dropdown(
          label: 'Layanan',
          items: [for (final d in controller.definitions) (d.id, d.title)],
          value: controller.optionId,
        ),
        gap,
        dropdown(
          label: 'Gedung (opsional)',
          items: [for (final f in controller.facilities) (f.id, f.name)],
          value: controller.facilityId,
        ),
        gap,
        text(controller.subjectC, 'Judul permintaan'),
        gap,
        text(controller.descriptionC, 'Keterangan (opsional)', lines: 3),
        gap,
        DropdownButtonFormField<String>(
          initialValue: controller.priority.value,
          decoration: appInputDecoration(theme, 'Prioritas'),
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
        ),
        gap,
        text(controller.subjectC, 'Keperluan'),
        ...period,
      ],
      GamsCreateKind.visit => [
        dropdown(
          label: 'Gedung',
          items: [for (final f in controller.facilities) (f.id, f.name)],
          value: controller.facilityId,
        ),
        gap,
        text(controller.visitorNameC, 'Nama tamu'),
        gap,
        text(
          controller.visitorPhoneC,
          'Telepon tamu (opsional)',
          type: TextInputType.phone,
        ),
        gap,
        text(controller.visitorCompanyC, 'Perusahaan tamu (opsional)'),
        gap,
        text(controller.subjectC, 'Keperluan kunjungan'),
      ],
    };
  }
}

/// A date and a time, picked one after the other.
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.label, required this.value});

  final String label;
  final Rxn<DateTime> value;

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
