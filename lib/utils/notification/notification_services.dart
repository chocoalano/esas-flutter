// lib/services/notification_service.dart

import 'package:esas/features/notification/presentation/routes/notification_routes.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class NotificationService extends GetxService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Inisialisasi notifikasi
  /// Siapkan kanal dan pengaturan notifikasi lokal.
  ///
  /// **Tidak meminta izin apa pun.** Dulu ia meminta izin di sini — lewat
  /// `permission_handler` di Android dan `IOSFlutterLocalNotifications` di iOS —
  /// dan `FirebaseMessagingService` meminta izin yang SAMA sekali lagi beberapa
  /// saat kemudian. Dua pustaka memiliki satu keputusan, dan keduanya berjalan
  /// dari bootstrap: dialog izin muncul sebelum orangnya sempat melihat satu
  /// layar pun, apalagi masuk.
  ///
  /// Sekarang izin diminta satu kali, oleh satu pemilik, sesudah sesi ada —
  /// lihat `FirebaseMessagingService.ensurePushRegistered`.
  Future<void> initialize() async {
    // === Initialization Settings (Android + iOS WAJIB) ===
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS (Darwin) init settings HARUS diset agar tidak error
    final DarwinInitializationSettings
    initializationSettingsIOS = DarwinInitializationSettings(
      // Jika ingin meminta permission di tahap init, set true.
      // Di atas kita sudah request manual, jadi set false agar tidak double prompt.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      // Jika butuh menangani notifikasi lokal saat app foreground di iOS < 10:
      // onDidReceiveLocalNotification: (id, title, body, payload) async {},
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    // Inisialisasi plugin notifikasi + handler tap
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Tangani ketika user tap notifikasi
        final payload = response.payload;
        if (payload != null) Get.offAllNamed(NotificationRoutes.notification);
      },
      onDidReceiveBackgroundNotificationResponse:
          _onDidReceiveBackgroundNotificationResponse,
    );
  }

  // Fungsi untuk menampilkan notifikasi
  Future<void> showNotification(String title, String message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'notification', // ID channel
          'notification', // Nama channel
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID unik
      title, // Judul notifikasi
      message, // Isi pesan
      platformChannelSpecifics, // Detail spesifik platform
      payload: 'Default_Payload', // Payload (opsional)
    );
  }
}

// Handler tap-notification saat background (Android 12+)
@pragma('vm:entry-point')
void _onDidReceiveBackgroundNotificationResponse(
  NotificationResponse response,
) {
  // Biasanya dibiarkan kosong; navigasi dilakukan saat app aktif.
}
