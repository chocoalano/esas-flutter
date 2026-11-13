import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../../../../core/ui/components/app_section_header.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../controllers/itms_ticket_create_controller.dart';

/// The form "Lapor" opens (ITMS-01).
class ItmsTicketCreateView extends GetView<ItmsTicketCreateController> {
  const ItmsTicketCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Laporkan kendala IT')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        // The services did not load: a retry, not an empty dropdown (UX-A07).
        if (controller.loadError.value case final failed?) {
          return AppErrorState(
            title: failed.isForbidden
                ? 'Tidak ada akses'
                : 'Daftar layanan IT belum dapat dimuat',
            message: failed.message,
            onRetry: failed.isForbidden ? null : controller.loadServices,
          );
        }

        const gap = SizedBox(height: AppSpacing.sm);

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
                  const AppSectionHeader(
                    title: 'Formulir Kendala IT',
                    subtitle: 'Isi detail masalah teknis yang Anda alami',
                    dense: true,
                    naturalCase: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int>(
                    initialValue: controller.serviceId.value,
                    isExpanded: true,
                    decoration: appInputDecoration(
                      theme,
                      'Layanan',
                      helperText:
                          'Pilih jenis layanan IT yang mengalami kendala.',
                      helperMaxLines: 2,
                    ),
                    items: [
                      for (final service in controller.services)
                        DropdownMenuItem(
                          value: service.id,
                          child: Text(service.name),
                        ),
                    ],
                    onChanged: (id) => controller.serviceId.value = id,
                  ),
                  gap,
                  TextField(
                    controller: controller.subjectC,
                    maxLength: ItmsTicketCreateController.subjectMax,
                    textInputAction: TextInputAction.next,
                    decoration: appInputDecoration(
                      theme,
                      'Judul kendala',
                      helperText:
                          'Tulis ringkasan singkat kendala yang dialami.',
                      helperMaxLines: 2,
                    ),
                  ),
                  gap,
                  TextField(
                    controller: controller.descriptionC,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: ItmsTicketCreateController.descriptionMax,
                    textInputAction: TextInputAction.done,
                    decoration: appInputDecoration(
                      theme,
                      'Uraian (opsional)',
                      helperText:
                          'Jelaskan kronologi, pesan error, atau lokasi ruangan.',
                      helperMaxLines: 2,
                    ),
                  ),
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
    if (!sent || !context.mounted) return;

    showSuccessSnackbar('Tiket kendala IT terkirim.');
    // `Navigator`, not `Get.back`: the latter closes the snackbar just shown
    // instead of the page. `true` asks the dashboard to reload.
    Navigator.of(context).pop(true);
  }
}
