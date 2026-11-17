import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_dialog.dart';

/// Informasi yang perlu dibaca sebelum melanjutkan dari halaman saat ini.
///
/// Memakai bentuk [AppDialog] yang sama dengan konfirmasi: sebelumnya dialog
/// ini rata kiri dengan ikon polos, sementara konfirmasi rata tengah dengan
/// ikon berkotak — dua dialog yang muncul berurutan di alur masuk terbaca
/// seperti dua aplikasi.
Future<void> showAppInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData? icon,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (BuildContext dialogContext) => AppDialog(
    icon: icon,
    tone: AppDialogTone.info,
    title: title,
    message: message,
    actions: <Widget>[
      AppDialog.button(
        label: 'Mengerti',
        onPressed: () => Navigator.of(dialogContext).pop(),
      ),
    ],
  ),
);

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
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppDialog(
      icon: icon,
      tone: destructive ? AppDialogTone.danger : AppDialogTone.brand,
      title: title,
      message: message,
      actions: <Widget>[
        AppDialog.button(
          label: cancelLabel,
          primary: false,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AppDialog.button(
          label: confirmLabel,
          destructive: destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
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
    message:
        'Anda akan menutup Absensas. Data yang sudah tersimpan tidak hilang.',
    confirmLabel: 'Keluar',
    cancelLabel: 'Tetap di sini',
    icon: Icons.logout_rounded,
  );

  if (shouldExit) {
    await SystemNavigator.pop();
  }
}
