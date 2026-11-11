import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../controllers/itms_ticket_create_controller.dart';

/// The form "Lapor" opens (ITMS-01).
class ItmsTicketCreateView extends GetView<ItmsTicketCreateController> {
  const ItmsTicketCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Laporkan kendala IT')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        const gap = SizedBox(height: AppSpacing.md);

        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            DropdownButtonFormField<int>(
              initialValue: controller.serviceId.value,
              isExpanded: true,
              decoration: appInputDecoration(theme, 'Layanan'),
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
              decoration: appInputDecoration(theme, 'Judul kendala'),
            ),
            gap,
            TextField(
              controller: controller.descriptionC,
              minLines: 4,
              maxLines: 8,
              maxLength: ItmsTicketCreateController.descriptionMax,
              textInputAction: TextInputAction.done,
              decoration: appInputDecoration(theme, 'Uraian (opsional)'),
            ),
            gap,
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
    if (!sent || !context.mounted) return;

    showSuccessSnackbar('Tiket kendala IT terkirim.');
    // `Navigator`, not `Get.back`: the latter closes the snackbar just shown
    // instead of the page. `true` asks the dashboard to reload.
    Navigator.of(context).pop(true);
  }
}
