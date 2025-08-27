// lib/services/notification_service.dart
import 'dart:io';

import 'package:esas/app/routes/app_pages.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService extends GetxService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Inisialisasi notifikasi
  Future<void> initialize() async {
    // === 1) Minta izin ===
    if (Platform.isAndroid) {
      // Android 13+ perlu runtime permission
      final status = await Permission.notification.status;
      if (status.isDenied || status.isRestricted) {
        await Permission.notification.request();
      }
    }

    // iOS: permission minta via plugin iOS
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // === 2) Initialization Settings (Android + iOS WAJIB) ===
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
        if (payload != null) Get.offAllNamed(Routes.NOTIFICATION);
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
