import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shows a customizable GetX Snackbar with theme integration.
///
/// Parameters:
/// - [title]: The title of the snackbar.
/// - [message]: The main message content of the snackbar.
/// - [backgroundColor]: Optional custom background color. Defaults to theme's surface color.
/// - [colorText]: Optional custom text color. Defaults to theme's onSurface color.
/// - [snackPosition]: Position of the snackbar (TOP or BOTTOM). Defaults to BOTTOM.
/// - [icon]: Optional icon to display.
void showCustomSnackbar({
  required String title,
  required String message,
  Color? backgroundColor,
  Color? colorText,
  SnackPosition snackPosition = SnackPosition.BOTTOM,
  IconData? icon,
}) {
  final ThemeData theme = Get.theme; // Get the current theme
  final ColorScheme colorScheme = theme.colorScheme;

  Get.snackbar(
    title,
    message,
    snackPosition: snackPosition,
    // Use provided color or fallback to theme's surface
    backgroundColor: backgroundColor ?? colorScheme.surface,
    // Use provided color or fallback to theme's onSurface
    colorText: colorText ?? colorScheme.onSurface,
    margin: const EdgeInsets.all(10),
    borderRadius: 8,
    // Use provided color for icon or fallback to theme's onSurface
    icon: icon != null
        ? Icon(icon, color: colorText ?? colorScheme.onSurface)
        : null,
    duration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 300),
    isDismissible: true,
    forwardAnimationCurve: Curves.easeOutBack,
    reverseAnimationCurve: Curves.easeInBack,
  );
}

/// Shows a success snackbar using theme's success colors.
///
/// Parameters:
/// - [message]: The success message.
/// - [title]: Optional title. Defaults to 'Berhasil'.
void showSuccessSnackbar(String message, {String title = 'Berhasil'}) {
  final ColorScheme colorScheme = Get.theme.colorScheme;
  showCustomSnackbar(
    title: title,
    message: message,
    // Use theme's primary color for success (or define a custom success color in your theme)
    backgroundColor: colorScheme.primary, // Often a good choice for success
    // Ensure text is legible on the background color
    colorText: colorScheme.onPrimary,
    icon: Icons
        .check_circle_outline_rounded, // Using rounded icon for modern look
  );
}

/// Shows an error snackbar using theme's error colors.
///
/// Parameters:
/// - [message]: The error message.
/// - [title]: Optional title. Defaults to 'Terjadi Kesalahan'.
void showErrorSnackbar(String message, {String title = 'Terjadi Kesalahan'}) {
  final ColorScheme colorScheme = Get.theme.colorScheme;
  showCustomSnackbar(
    title: title,
    message: message,
    // Directly use theme's error color
    backgroundColor: colorScheme.error,
    // Ensure text is legible on the error color
    colorText: colorScheme.onError,
    icon: Icons.error_outline_rounded, // Using rounded icon
  );
}

/// Shows a warning snackbar using theme's warning/tertiary colors.
///
/// Parameters:
/// - [message]: The warning message.
/// - [title]: Optional title. Defaults to 'Peringatan'.
void showWarningSnackbar(String message, {String title = 'Peringatan'}) {
  final ColorScheme colorScheme = Get.theme.colorScheme;
  showCustomSnackbar(
    title: title,
    message: message,
    // Using theme's secondary or tertiary for warning, or a custom blend
    backgroundColor:
        colorScheme.tertiary, // Tertiary is often good for warnings/accent
    // Ensure text is legible on the warning color
    colorText: colorScheme.onTertiary,
    icon: Icons.warning_amber_rounded, // Using rounded icon
  );
}
