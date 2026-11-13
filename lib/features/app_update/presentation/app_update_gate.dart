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
          if (controller.showMigration && controller.migration.value != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                child: MigrationNoticeCard(
                  controller: controller,
                  replacement: controller.migration.value!,
                ),
              ),
            ),
          if (!required &&
              !controller.showMigration &&
              controller.showOptional &&
              info != null)
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
              // Scrolls when the steps and notes do not fit (small phone,
              // large text); the button below stays on screen.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                            Text(
                              info.releaseNotes!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          if (!info.opensStore) ...[
                            const SizedBox(height: 16),
                            const _InstallSteps(),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'Pemasangan gagal, atau layar ini muncul lagi '
                            'setelah memasang? Silakan hubungi HR/IT dan '
                            'tunjukkan keterangan di bawah.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                          Obx(() {
                            final installed =
                                controller.installedBuildNumber.value;

                            return installed == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Terpasang: build $installed · '
                                      'Dibutuhkan: build ${info.buildNumber}',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
            if (!info.opensStore)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  'Setelah terunduh, buka file .apk untuk memasang. '
                  'Bila gagal, hubungi HR/IT.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Obx(
              () => controller.openFailed.value
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Text(
                        'Tautan pembaruan tidak dapat dibuka. Periksa koneksi '
                        'lalu coba lagi.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
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

/// Tells the person Absensas has moved to a new official app. It never blocks:
/// "Nanti" closes it, nothing is installed, opened or removed for them.
class MigrationNoticeCard extends StatelessWidget {
  const MigrationNoticeCard({
    super.key,
    required this.controller,
    required this.replacement,
  });

  static const String title = 'Absensas Pindah ke Aplikasi Resmi Baru';
  static const String body =
      'Pasang aplikasi Absensas yang baru dan masuk menggunakan akun Anda. '
      'Data absensi dan pekerjaan tetap tersimpan di server. '
      'Untuk menggunakan absensi pada aplikasi baru, lakukan aktivasi perangkat melalui HR. '
      'Hapus aplikasi lama hanya setelah aplikasi baru berfungsi.';

  final AppUpdateController controller;
  final AppReplacement replacement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(body, style: theme.textTheme.bodyMedium),
                      if ((replacement.message ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          replacement.message!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      Obx(
                        () => controller.migrationOpenFailed.value
                            ? Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Tautan unduhan tidak dapat dibuka. Periksa koneksi lalu coba lagi.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    key: const Key('migration-dismiss'),
                    onPressed: controller.dismissMigration,
                    child: const Text('Nanti'),
                  ),
                  TextButton(
                    key: const Key('migration-open'),
                    onPressed: controller.openReplacement,
                    child: const Text('Unduh Aplikasi Baru'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What Google Drive and Android's installer will ask for once the person
/// leaves the app. The app cannot see those screens, so it says beforehand.
class _InstallSteps extends StatelessWidget {
  const _InstallSteps();

  static const List<String> steps = [
    'Ketuk Download / Update Sekarang. Bila terbuka Google Drive, ketuk '
        'tombol Download.',
    'Buka file .apk yang terunduh. Bila ponsel meminta, izinkan pemasangan '
        'dari sumber ini.',
    'Ketuk Update atau Instal, lalu buka kembali aplikasi.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cara memasang', style: theme.textTheme.titleSmall),
            for (final (index, step) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${index + 1}.', style: theme.textTheme.bodyMedium),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(step, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
