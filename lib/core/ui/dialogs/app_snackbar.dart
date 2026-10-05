import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Helper utama untuk menampilkan snackbar dengan integrasi tema.
void _showSnackbar({
  required String title,
  required String message,
  required Color backgroundColor,
  required Color colorText,
  required IconData icon,
  SnackPosition position = SnackPosition.TOP,
}) {
  Get.snackbar(
    title,
    message,
    snackPosition: position,
    backgroundColor: backgroundColor,
    colorText: colorText,
    margin: const EdgeInsets.all(12),
    borderRadius: 10,
    icon: Icon(icon, color: colorText),
    duration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 250),
    isDismissible: true,
    forwardAnimationCurve: Curves.easeOutBack,
    reverseAnimationCurve: Curves.easeInBack,
  );
}

/// Success snackbar (hijau / primary).
void showSuccessSnackbar(String message, {String title = 'Berhasil'}) {
  final scheme = Get.theme.colorScheme;
  _showSnackbar(
    title: title,
    message: message,
    backgroundColor: scheme.primary,
    colorText: scheme.onPrimary,
    icon: Icons.check_circle_outline_rounded,
  );
}

/// Error snackbar (merah).
void showErrorSnackbar(String message, {String title = 'Terjadi Kesalahan'}) {
  final scheme = Get.theme.colorScheme;
  _showSnackbar(
    title: title,
    message: message,
    backgroundColor: scheme.error,
    colorText: scheme.onError,
    icon: Icons.error_outline_rounded,
  );
}

/// Warning snackbar (kuning/tertiary).
void showWarningSnackbar(String message, {String title = 'Peringatan'}) {
  final scheme = Get.theme.colorScheme;
  _showSnackbar(
    title: title,
    message: message,
    backgroundColor: scheme.tertiary,
    colorText: scheme.onTertiary,
    icon: Icons.warning_amber_rounded,
  );
}

/// Info snackbar (biru/secondary).
void showInfoSnackbar(String message, {String title = 'Info'}) {
  final scheme = Get.theme.colorScheme;
  _showSnackbar(
    title: title,
    message: message,
    backgroundColor: scheme.secondary,
    colorText: scheme.onSecondary,
    icon: Icons.info_outline_rounded,
  );
}
