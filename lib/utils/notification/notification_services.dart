// lib/services/notification_service.dart

import 'dart:convert';

import 'package:esas/features/notification/data/services/notification_sync_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class NotificationService extends GetxService {
  static const channelId = 'esas_attendance';
  int _nextNotificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
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
        _openPayload(payload);
      },
      onDidReceiveBackgroundNotificationResponse:
          _onDidReceiveBackgroundNotificationResponse,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            'Notifikasi Absensas',
            importance: Importance.high,
          ),
        );
    final launch = await flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _openPayload(launch?.notificationResponse?.payload);
    }
  }

  void _openPayload(String? payload) {
    if (!Get.isRegistered<NotificationSyncService>()) return;
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(payload ?? '{}');
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Notifications displayed by older builds carried a fixed string.
    }
    Get.find<NotificationSyncService>().open(data);
  }

  // Fungsi untuk menampilkan notifikasi
  Future<void> showNotification(
    String title,
    String message, {
    Map<String, dynamic> data = const {},
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          'Notifikasi Absensas',
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
      _nextNotificationId = (_nextNotificationId + 1) % 2147483647,
      title, // Judul notifikasi
      message, // Isi pesan
      platformChannelSpecifics, // Detail spesifik platform
      payload: jsonEncode(data),
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
