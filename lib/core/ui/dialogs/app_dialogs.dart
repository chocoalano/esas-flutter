import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Dialog konfirmasi baku aplikasi.
///
/// Lima layar sebelumnya masing-masing menyusun `AlertDialog` "Keluar Aplikasi"
/// sendiri, dan dua layar lain memakai `Get.defaultDialog` dengan gaya tombol
/// yang ditulis ulang setiap kali. Satu dialog berarti satu bentuk, satu bobot
/// tombol, dan satu tempat untuk memperbaikinya.
///
/// Aksi merusak diberi warna error dan diletakkan di kanan — posisi yang sama
/// dengan aksi utama pada dialog lain, karena memindahkannya justru membuat
/// orang menekan tombol yang salah karena kebiasaan.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Lanjutkan',
  String cancelLabel = 'Batal',
  IconData? icon,
  bool destructive = false,
}) async {
  final theme = Theme.of(context);
  final palette = theme.palette;
  final Color accent = destructive
      ? palette.danger.foreground
      : theme.colorScheme.primary;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: icon == null
          ? null
          : Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: destructive
                    ? palette.danger.background
                    : palette.brandSubtle,
                borderRadius: AppRadii.xlAll,
                border: Border.all(
                  color: destructive
                      ? palette.danger.border
                      : accent.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
      iconPadding: const EdgeInsets.only(top: AppSpacing.xxl),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(color: palette.textMuted),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Menutup aplikasi setelah konfirmasi.
///
/// Dipasang pada [PopScope] di setiap tab akar. Perilakunya tidak berubah dari
/// sebelumnya; yang berubah hanya bahwa kelima salinannya kini satu.
Future<void> confirmExitApp(BuildContext context) async {
  final bool shouldExit = await showAppConfirmDialog(
    context,
    title: 'Keluar aplikasi?',
    message: 'Anda akan menutup ESAS. Data yang sudah tersimpan tidak hilang.',
    confirmLabel: 'Keluar',
    cancelLabel: 'Tetap di sini',
    icon: Icons.logout_rounded,
  );

  if (shouldExit) {
    await SystemNavigator.pop();
  }
}
