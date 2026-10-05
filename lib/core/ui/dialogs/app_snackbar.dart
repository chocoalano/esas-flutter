import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Menampilkan satu snackbar, dengan penundaan bila frame sedang dibangun.
///
/// `Get.snackbar` menyisipkan overlay lewat `Get.overlayContext`, yang di dalam
/// GetX berbunyi:
///
/// ```dart
/// key.currentState?.overlay?.context.visitChildElements((element) { … });
/// ```
///
/// `visitChildElements()` haram dipanggil selama fase build — daftar anak masih
/// berubah, jadi Flutter melemparkan
/// `FlutterError (visitChildElements() called during build)`.
///
/// Itu bukan kasus teoretis di aplikasi ini. GetX menjalankan `onInit()` sebuah
/// controller ketika widget-nya pertama kali dibangun, dan beberapa `onInit`
/// memanggil snackbar sebelum `await` yang pertama — misalnya
/// `AnnouncementDetailController` saat id rute tidak terkirim. Dari sudut
/// pandang pemanggil, itu kode yang wajar; yang tidak wajar adalah sebuah
/// pemberitahuan yang menjatuhkan aplikasi.
///
/// Maka penjadwalannya diurus di sini, satu kali, alih-alih meminta lima puluh
/// pemanggil mengingat aturan siklus hidup GetX. Bila kita sedang berada di
/// tengah frame, penampilannya ditunda sampai frame itu selesai; di luar itu ia
/// tampil seketika seperti sebelumnya.
void _present({
  required String title,
  required String message,
  required AppTone tone,
  required IconData icon,
  required SnackPosition position,
}) {
  final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
  final bool duringFrame =
      phase == SchedulerPhase.persistentCallbacks ||
      phase == SchedulerPhase.midFrameMicrotasks;

  void show() {
    // Bila aplikasi sudah tidak punya konteks — misalnya snackbar menyusul
    // sebuah `Get.offAll` yang sedang berlangsung — diamkan saja. Sebuah
    // pemberitahuan yang datang terlambat tidak sepadan dengan galat.
    if (Get.context == null) return;

    Get.snackbar(
      title,
      message,
      snackPosition: position,
      // Latar permukaan dengan garis 1px, bukan blok warna pekat. Snackbar
      // adalah satu-satunya elemen yang muncul di atas layar apa pun, jadi ia
      // harus terbaca sebagai bagian dari aplikasi, bukan sebagai sisipan.
      backgroundColor: tone.background,
      colorText: tone.foreground,
      borderColor: tone.border,
      borderWidth: 1,
      margin: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadii.lg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + 2,
      ),
      icon: Icon(icon, size: 20, color: tone.foreground),
      shouldIconPulse: false,
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 220),
      isDismissible: true,
      // `easeOutBack` melampaui posisi akhirnya lalu memantul balik. Pantulan
      // itu menarik perhatian ke gerakannya, bukan ke pesannya.
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      titleText: Text(
        title,
        style: Get.textTheme.titleSmall?.copyWith(color: tone.foreground),
      ),
      messageText: Text(
        message,
        style: Get.textTheme.bodySmall?.copyWith(color: tone.foreground),
      ),
    );
  }

  if (duringFrame) {
    // Kita sudah berada di dalam sebuah frame, jadi callback ini pasti
    // terpanggil — `addPostFrameCallback` sendiri tidak menjadwalkan frame baru.
    SchedulerBinding.instance.addPostFrameCallback((_) => show());
    return;
  }

  show();
}

/// Nada warna yang berlaku saat ini. Dibaca saat pemanggilan, bukan saat
/// penampilan, supaya snackbar yang ditunda tetap memakai tema yang sedang
/// aktif ketika kejadiannya berlangsung.
AppPalette get _palette => Get.theme.palette;

/// Snackbar sukses.
void showSuccessSnackbar(String message, {String title = 'Berhasil'}) {
  _present(
    title: title,
    message: message,
    tone: _palette.success,
    icon: Icons.check_circle_outline_rounded,
    position: SnackPosition.TOP,
  );
}

/// Snackbar galat.
void showErrorSnackbar(String message, {String title = 'Terjadi Kesalahan'}) {
  _present(
    title: title,
    message: message,
    tone: _palette.danger,
    icon: Icons.error_outline_rounded,
    position: SnackPosition.TOP,
  );
}

/// Snackbar peringatan.
void showWarningSnackbar(String message, {String title = 'Peringatan'}) {
  _present(
    title: title,
    message: message,
    tone: _palette.warning,
    icon: Icons.warning_amber_rounded,
    position: SnackPosition.TOP,
  );
}

/// Snackbar informasi.
void showInfoSnackbar(String message, {String title = 'Info'}) {
  _present(
    title: title,
    message: message,
    tone: _palette.info,
    icon: Icons.info_outline_rounded,
    position: SnackPosition.TOP,
  );
}
