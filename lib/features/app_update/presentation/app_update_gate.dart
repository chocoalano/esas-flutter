import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/app_version_info.dart';
import 'app_update_controller.dart';

/// Sits above the navigator (GetMaterialApp `builder`), so whatever route is
/// showing, a mandatory update covers it and an optional one is offered on top.
class AppUpdateGate extends StatelessWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppUpdateController>()) {
      return child;
    }

    final controller = Get.find<AppUpdateController>();

    return Obx(() {
      final info = controller.latest.value;
      final required =
          controller.requirement.value == UpdateRequirement.required;

      return Stack(
        children: [
          child,
          if (required && info != null)
            Positioned.fill(
              child: ForcedUpdateView(controller: controller, info: info),
            ),
          if (!required && controller.showOptional && info != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                child: OptionalUpdateCard(controller: controller, info: info),
              ),
            ),
        ],
      );
    });
  }
}

/// Covers the app until the installed build catches up. No skip; the system
/// back button reaches the routes underneath, which this keeps covered.
class ForcedUpdateView extends StatelessWidget {
  const ForcedUpdateView({
    super.key,
    required this.controller,
    required this.info,
  });

  final AppUpdateController controller;
  final AppVersionInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.system_update,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Pembaruan Wajib',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Versi ${info.version} harus dipasang sebelum aplikasi dapat digunakan kembali.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if ((info.releaseNotes ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      info.releaseNotes!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Obx(
                () => controller.openFailed.value
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Tautan pembaruan tidak dapat dibuka. Periksa koneksi lalu coba lagi.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              FilledButton.icon(
                key: const Key('app-update-download'),
                onPressed: controller.openDownload,
                icon: const Icon(Icons.download),
                label: Obx(
                  () => Text(
                    controller.openFailed.value
                        ? 'Coba Lagi'
                        : 'Download / Update Sekarang',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offers a newer build; the person may close it and carry on.
class OptionalUpdateCard extends StatelessWidget {
  const OptionalUpdateCard({
    super.key,
    required this.controller,
    required this.info,
  });

  final AppUpdateController controller;
  final AppVersionInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update Tersedia', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Versi ${info.version} sudah tersedia.',
              style: theme.textTheme.bodyMedium,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('app-update-dismiss'),
                  onPressed: controller.dismissOptional,
                  child: const Text('Nanti'),
                ),
                TextButton(
                  key: const Key('app-update-open'),
                  onPressed: controller.openDownload,
                  child: const Text('Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
