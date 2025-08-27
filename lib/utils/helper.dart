import 'package:esas/app/widgets/views/snackbar.dart';
import 'package:esas/utils/api_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Kembalikan URL gambar penuh, atau path apa adanya jika sudah full URL.
String imageUrl(String path) {
  if (path.startsWith('http')) return path;
  return '$baseImageUrl$path';
}

/// Parse [dateString] (ISO-8601) dan format ke 'dd MMMM yyyy' bahasa Indonesia.
/// Contoh: '2025-07-09T02:43:31.000Z' → '09 Juli 2025'
String formatDateIndo(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    return DateFormat('dd MMMM yyyy', 'id').format(date);
  } catch (e) {
    // Jika gagal parse, kembalikan input mentah
    return dateString;
  }
}

/// Parse [dateString] (ISO-8601) dan format ke 'EEEE, dd MMMM yyyy' lokal Indonesia.
/// Contoh: '2025-07-09T02:43:31.000Z' → 'Rabu, 09 Juli 2025'
String formatFullDateIndo(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    return DateFormat('EEEE, dd MMMM yyyy', 'id').format(date);
  } catch (e) {
    return dateString;
  }
}

String limitString(String? text, {int maxLength = 20}) {
  if (text == null || text.isEmpty) {
    return 'N/A';
  }
  if (text.length <= maxLength) {
    return text;
  }
  final actualMaxLength = (maxLength < 3) ? 3 : maxLength;
  return '${text.substring(0, actualMaxLength - 3)}...';
}

// untuk repose api
void showApiError(int? code, dynamic body) {
  String msg;
  switch (code) {
    case 400:
      msg = 'Permintaan tidak valid.';
      break;
    case 401:
      msg = 'Sesi Anda berakhir. Mohon login kembali.';
      break;
    case 403:
      msg = 'Anda tidak memiliki izin untuk tindakan ini.';
      break;
    case 404:
      msg = 'Data tidak ditemukan.';
      break;
    case 409: // Conflict, e.g., already approved/rejected
      msg = 'Konflik data: ${body['message'] ?? 'Perizinan sudah diproses.'}';
      break;
    case 500:
      msg = 'Kesalahan server internal.';
      break;
    default:
      msg = 'Terjadi kesalahan tidak dikenal. Kode: $code';
      break;
  }
  if (kDebugMode && body != null) debugPrint('API Error ($code): $body');
  showErrorSnackbar(msg);
}

InputDecoration inputDecoration(
  ThemeData theme,
  String labelText, {
  String? hintText,
  Widget? suffixIcon,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixIcon:
        suffixIcon, // This will display the calendar icon or visibility toggle
    // --- ASSIGN IT HERE ---
    prefixIcon: prefixIcon, // This will display the leading icon
    border: OutlineInputBorder(
      // Default border for all states
      borderRadius: BorderRadius.circular(
        12,
      ), // Menggunakan 12 untuk konsistensi dengan contoh Anda
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: theme.colorScheme.outline.withAlpha(20),
      ), // Warna outline yang lebih lembut
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
      borderRadius: BorderRadius.circular(12),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.error, width: 2.0),
      borderRadius: BorderRadius.circular(12),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.error, width: 2.0),
      borderRadius: BorderRadius.circular(12),
    ),
    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
    hintStyle: TextStyle(
      color: theme.colorScheme.onSurfaceVariant.withAlpha(20),
    ),
    // Menambahkan fill color untuk tampilan yang lebih modern
    fillColor: theme.colorScheme.surfaceContainerLowest,
    filled: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  return parts.take(2).map((e) => e[0]).join().toUpperCase();
}

Widget buildAvatar(
  BuildContext context, {
  required String userName,
  String? imageUrl,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  final hasImage = imageUrl != null && imageUrl.isNotEmpty;

  return CircleAvatar(
    radius: 24,
    backgroundColor: cs.primary,
    foregroundImage: hasImage ? NetworkImage(imageUrl) : null,
    onForegroundImageError: hasImage
        ? (_, __) {
            // opsional log
            // debugPrint("Gagal load avatar: $imageUrl");
          }
        : null,
    child: Text(
      _initials(userName),
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onPrimaryContainer,
      ),
    ),
  );
}
