import 'package:esas/app/routes/app_pages.dart';
import 'package:esas/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/permit_create_controller.dart';

class PermitCreate extends GetView<PermitCreateController> {
  const PermitCreate({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        Get.offAllNamed(
          Routes.PERMIT_LIST,
          arguments: controller.createType.value,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Obx(
            () => Text(
              'Buat ${controller.createType.value.type}',
              style:
                  theme.appBarTheme.titleTextStyle ??
                  theme.textTheme.titleLarge?.copyWith(
                    color: theme.appBarTheme.foregroundColor,
                  ),
            ),
          ),
          backgroundColor: theme.appBarTheme.backgroundColor,
          foregroundColor: theme.appBarTheme.foregroundColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Get.offAllNamed(
              Routes.PERMIT_LIST,
              arguments: controller.createType.value,
            ),
          ),
        ),
        body: SafeArea(
          child: Obx(() {
            if (controller.isLoading.value) {
              return _buildLoading(theme);
            }
            return _buildForm(context, theme);
          }),
        ),
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Memuat data formulir...', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, ThemeData theme) {
    return Form(
      key: controller.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDropdownSchedule(theme),
            _spacer(),
            _buildTextFormField(
              controller.permitNumberC,
              theme,
              'Nomor Izin',
              validator: (val) {
                if (val == null || val.isEmpty) return 'Nomor Izin wajib diisi';
                if (val.length > 50) return 'Nomor Izin maksimal 50 karakter';
                return null;
              },
            ),
            _spacer(),
            if (controller.selectedPermitTypeId.value == 15) ...[
              _buildTimePickerField(
                context,
                theme,
                'Jam Masuk Penyesuaian',
                controller.timeinAdjustC,
              ),
              _spacer(),
              _buildTimePickerField(
                context,
                theme,
                'Jam Pulang Penyesuaian',
                controller.timeoutAdjustC,
                validateAfter: controller.timeinAdjustC,
              ),
              _spacer(),
            ],
            if (controller.selectedPermitTypeId.value == 16) ...[
              _buildDropdownShift(
                theme,
                'Shift Saat Ini (opsional)',
                controller.selectedCurrentShiftId,
              ),
              _spacer(),
              _buildDropdownShift(
                theme,
                'Shift Penyesuaian (opsional)',
                controller.selectedAdjustShiftId,
              ),
              _spacer(),
            ],
            if (controller.selectedScheduleId.value != null) ...[
              _buildDatePickerField(
                context,
                theme,
                'Tanggal Mulai',
                controller.startDateC,
              ),
              _spacer(),
              _buildDatePickerField(
                context,
                theme,
                'Tanggal Selesai',
                controller.endDateC,
                validateAfterDate: controller.startDateC,
              ),
            ],
            _spacer(),
            _buildTimePickerField(
              context,
              theme,
              'Jam Mulai',
              controller.startTimeC,
              isRequired: true,
            ),
            _spacer(),
            _buildTimePickerField(
              context,
              theme,
              'Jam Selesai',
              controller.endTimeC,
              isRequired: true,
            ),
            _spacer(),
            _buildTextFormField(
              controller.notesC,
              theme,
              'Catatan (opsional)',
              maxLines: 3,
              maxLength: 255,
            ),
            _spacer(),
            _buildFilePicker(theme),
            const SizedBox(height: 24),
            _buildSubmitButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSchedule(ThemeData theme) => Obx(
    () => DropdownButtonFormField<int>(
      value: controller.selectedScheduleId.value,
      decoration: inputDecoration(theme, 'Jadwal Kerja'),
      items: controller.scheduleList
          .map(
            (item) => DropdownMenuItem<int>(
              value: item.id,
              child: Text(
                item.formattedWorkDay,
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
    Rx<int?> selectedValue,
  ) => DropdownButtonFormField<int>(
    value: selectedValue.value,
    decoration: inputDecoration(theme, label),
    items: controller.shiftList
        .map(
          (item) => DropdownMenuItem<int>(
            value: item.id,
            child: Text(item.name ?? 'Jam kerja tidak diketahui'),
          ),
        )
        .toList(),
    onChanged: (v) => selectedValue.value = v,
  );

  Widget _buildTextFormField(
    TextEditingController ctrl,
    ThemeData theme,
    String label, {
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
  }) => TextFormField(
    controller: ctrl,
    decoration: inputDecoration(theme, label),
    validator: validator,
    maxLines: maxLines,
    maxLength: maxLength,
  );

  Widget _buildDatePickerField(
    BuildContext context,
    ThemeData theme,
    String label,
    TextEditingController controller, {
    TextEditingController? validateAfterDate,
  }) => TextFormField(
    controller: controller,
    readOnly: true,
    onTap: () async => await this.controller.pickDate(context, controller),
    decoration: inputDecoration(
      theme,
      label,
      hintText: 'YYYY-MM-DD',
      suffixIcon: Icon(
        Icons.calendar_today,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    validator: (val) {
      if (val == null || val.isEmpty) return '$label wajib diisi';
      try {
        final DateTime date = DateTime.parse(val);
        if (validateAfterDate != null) {
          final DateTime afterDate = DateTime.parse(validateAfterDate.text);
          if (label.contains('Selesai') && date.isBefore(afterDate)) {
            return 'Harus setelah tanggal mulai';
          }
          if (label.contains('Mulai') && date.isAfter(afterDate)) {
            return 'Harus sebelum tanggal selesai';
          }
        }
      } catch (_) {
        return 'Format tanggal tidak valid';
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
  }) => TextFormField(
    controller: controller,
    readOnly: true,
    onTap: () => this.controller.pickTime(context, controller),
    decoration: inputDecoration(
      theme,
      label,
      hintText: 'HH:mm',
      suffixIcon: Icon(
        Icons.access_time,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    validator: (val) {
      final cleanedVal = val
          ?.replaceAll(
            RegExp(r'[^\x20-\x7E]'),
            '',
          ) // bersihkan karakter non-printable
          .replaceAll('.', ':') // ubah titik jadi titik dua
          .trim();

      if (!isRequired && (cleanedVal == null || cleanedVal.isEmpty)) {
        return null;
      }
      if (cleanedVal == null || cleanedVal.isEmpty) return '$label wajib diisi';
      final reg = RegExp(r'^\d{2}:\d{2}$');

      if (!reg.hasMatch(cleanedVal)) return 'Format jam tidak valid (HH:mm)';
      if (validateAfter != null &&
          validateAfter.text.isNotEmpty &&
          cleanedVal.compareTo(validateAfter.text.trim()) <= 0) {
        return 'Harus setelah ${validateAfter.text}';
      }
      return null;
    },
  );

  Widget _buildFilePicker(ThemeData theme) => Row(
    children: [
      Expanded(
        child: Obx(
          () => Text(
            controller.selectedFile.value?.name ?? 'Belum pilih file',
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: controller.pickFile,
        icon: const Icon(Icons.attach_file),
        label: const Text('Pilih File'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: theme.colorScheme.onSecondary,
        ),
      ),
    ],
  );

  Widget _buildSubmitButton(ThemeData theme) => Obx(
    () => ElevatedButton(
      onPressed: controller.isSubmitting.value ? null : controller.createPermit,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
      ),
      child: controller.isSubmitting.value
          ? CircularProgressIndicator(color: theme.colorScheme.onPrimary)
          : Text(
              'Simpan Permohonan',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
    ),
  );

  Widget _spacer() => const SizedBox(height: 16);
}
