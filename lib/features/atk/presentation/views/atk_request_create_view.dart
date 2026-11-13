import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_inline_notice.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../controllers/atk_request_create_controller.dart';
import 'atk_view_helpers.dart';

/// Asking GA for office supplies: which item, where to pick it up, how many.
class AtkRequestCreateView extends GetView<AtkRequestCreateController> {
  const AtkRequestCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Minta ATK')),
      body: Obx(() {
        final loadError = controller.loadError.value;

        if (controller.isLoading.value) {
          return const AtkDetailSkeleton();
        }

        // Without the items and locations there is nothing to choose from;
        // an empty dropdown would only look like a broken form.
        if (loadError != null) {
          return AppErrorState(
            title: 'Gagal memuat daftar barang',
            message: loadError.message,
            onRetry: controller.loadOptions,
          );
        }

        final busy = controller.isSubmitting.value;
        final nothingToPick =
            controller.items.isEmpty || controller.locations.isEmpty;
        final unit = controller.selectedItem?.unit;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (controller.items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: AppInlineNotice(
                  tone: AppNoticeTone.warning,
                  message:
                      'Belum ada barang ATK yang dapat diminta. Hubungi tim GA.',
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: controller.itemId.value,
                isExpanded: true,
                decoration: appInputDecoration(
                  theme,
                  'Barang',
                  helperText: 'Pilih alat tulis kantor yang Anda perlukan.',
                ),
                items: [
                  for (final item in controller.items)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy ? null : (id) => controller.itemId.value = id,
              ),
            const SizedBox(height: 12),
            if (controller.locations.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: AppInlineNotice(
                  tone: AppNoticeTone.warning,
                  message:
                      'Belum ada lokasi pengambilan terdaftar. Hubungi tim GA.',
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: controller.locationId.value,
                isExpanded: true,
                decoration: appInputDecoration(
                  theme,
                  'Lokasi pengambilan',
                  helperText: 'Tempat Anda mengambil barangnya.',
                ),
                items: [
                  for (final place in controller.locations)
                    DropdownMenuItem(
                      value: place.id,
                      child: Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (id) => controller.locationId.value = id,
              ),
            const SizedBox(height: 12),
            _QuantityField(controller: controller, unit: unit, enabled: !busy),
            if (controller.error.value case final message?) ...[
              const SizedBox(height: 12),
              AppInlineNotice(message: message),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: 'Kirim permintaan',
              icon: Icons.send_rounded,
              busy: busy,
              onPressed: busy || nothingToPick
                  ? null
                  : () async {
                      final number = await controller.submit();
                      if (number != null) Get.back(result: number);
                    },
            ),
          ],
        );
      }),
    );
  }
}

/// The quantity: typed, or stepped with − and +. Never below one.
class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.controller,
    required this.unit,
    required this.enabled,
  });

  final AtkRequestCreateController controller;
  final String? unit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.outlined(
          tooltip: 'Kurangi jumlah',
          onPressed: enabled ? controller.decrement : null,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller.quantityC,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: appInputDecoration(
              theme,
              'Jumlah',
              helperText: unit == null ? 'Minimal 1.' : 'Dalam $unit.',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Tambah jumlah',
          onPressed: enabled ? controller.increment : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
