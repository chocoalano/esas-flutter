import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/ui/dialogs/app_dialogs.dart';

/// Shown when a device request came back 401.
///
/// By then `ApiClient` has already ended the session and opened the sign-in
/// screen, which on its own says nothing about why. The usual reason here is
/// not an expired session but a lost answer: the enrolment or proof reached
/// the server, which replaced the token, and the reply never arrived. Signing
/// in again is then all it takes — the phone still holds the enrolled key.
Future<void> showDeviceSessionEnded() async {
  // Let the sign-in route the 401 handler pushed settle first.
  await WidgetsBinding.instance.endOfFrame;

  final context = Get.overlayContext ?? Get.context;

  if (context == null || !context.mounted) return;

  await showAppInfoDialog(
    context,
    icon: Icons.login_rounded,
    title: deviceSessionEndedTitle,
    message: deviceSessionEndedMessage,
  );
}

const String deviceSessionEndedTitle = 'Silakan Masuk Kembali';

const String deviceSessionEndedMessage =
    'Sesi Anda berakhir saat memeriksa perangkat absensi. Masuk kembali, lalu '
    'buka Absensi. Bila perangkat ini sudah terdaftar, Anda tidak perlu '
    'meminta kode baru dari HR.';
