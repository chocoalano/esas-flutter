import 'package:esas/app/routes/app_pages.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/views/snackbar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // Untuk debugPrint
import 'package:get/get.dart';

import '../../utils/notification/notification_services.dart'; // Sesuaikan path jika berbeda

// --- Global Background Message Handler ---
// Penting: Fungsi ini HARUS tetap di level teratas (di luar class manapun).
// Firebase memanggilnya dalam isolat Dart terpisah ketika aplikasi di-background/terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background message: ${message.messageId}");
  debugPrint("Data: ${message.data}");
  debugPrint("Notification body: ${message.notification?.body}");

  NotificationService().showNotification(
    message.notification?.title ?? "Background Notification",
    message.notification?.body ?? "New background message",
  );
}

class FirebaseMessagingService extends GetxService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late final NotificationService _notificationService;
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  // RxString untuk menyimpan token FCM (opsional, jika ingin ditampilkan di UI)
  final RxString _fcmToken = ''.obs;
  String get fcmToken => _fcmToken.value;

  @override
  void onInit() {
    super.onInit();
    // Temukan instance NotificationService yang sudah terdaftar
    _notificationService = Get.find<NotificationService>();

    // Panggil inisialisasi listener Firebase Messaging
    _initializeFirebaseMessagingListeners();
  }

  /// Menginisialisasi semua listener Firebase Messaging (permissions, token, foreground, background, opened app, initial message).
  Future<void> _initializeFirebaseMessagingListeners() async {
    // 1. Meminta izin notifikasi dari pengguna.
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      // Tambahkan kembali criticalAlert, provisional, dll. jika diperlukan
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
        debugPrint('Notification permission granted.');
        break;
      case AuthorizationStatus.provisional:
        debugPrint('Provisional notification permission granted.');
        break;
      default:
        debugPrint('Notification permission denied.');
    }

    // 2. Mengambil dan mencetak token FCM saat ini.
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      debugPrint("FCM Token: $token");
      _fcmToken.value = token; // Simpan token ke RxString
      setupToken(_fcmToken.value);
    } else {
      debugPrint("Unable to get FCM Token.");
      _fcmToken.value = '';
    }

    // 3. Menangani event FCM Token Refresh.
    _firebaseMessaging.onTokenRefresh.listen(
      (newToken) {
        debugPrint("FCM Token Refreshed: $newToken");
        _fcmToken.value = newToken; // Update token ke RxString
        setupToken(_fcmToken.value);
      },
      onError: (err) {
        debugPrint("FCM Token Refresh Error: $err");
      },
    );

    // 4. Mengatur handler pesan background global.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Menangani Pesan Foreground.
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint("Foreground message: ${message.data}");
      _notificationService.showNotification(
        message.notification?.title ?? "New Notification",
        message.notification?.body ?? "You have a new message",
      );
    });

    // 6. Menangani Pesan saat aplikasi dibuka dari keadaan terminated/background.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened app. Data: ${message.data}');
      _handleNotificationNavigation(message.data);
    });

    // 7. Mengambil pesan awal jika aplikasi diluncurkan dari keadaan terminated oleh notifikasi.
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("Initial message opened app: ${initialMessage.data}");
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  /// Helper method untuk menangani navigasi berdasarkan data notifikasi.
  /// Ini bisa diperluas untuk mem-parsing kunci spesifik dari data.
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Contoh: Navigasi ke halaman NOTIFICATION, Anda bisa menambahkan argumen jika diperlukan
    Get.toNamed(Routes.NOTIFICATION, arguments: data);

    // Contoh logika navigasi yang lebih kompleks:
    // if (data.containsKey('route_name')) {
    //   Get.toNamed(data['route_name'], arguments: data);
    // } else if (data.containsKey('product_id')) {
    //   Get.toNamed(Routes.PRODUCT_DETAIL, arguments: data['product_id']);
    // }
  }

  // Metode opsional untuk mengambil token FCM saat ini dari luar service
  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  // Metode opsional untuk subscribe/unsubscribe ke topik
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  Future<void> setupToken(String token) async {
    Map<String, dynamic> datapost = {'token': token};
    debugPrint("ini data post setup token : $datapost");
    final response = await _apiProvider.post(
      '/general-module/auth/set-token',
      datapost,
    );
    if (response.statusCode == 200) {
      debugPrint("fcm ditetapkan");
      // showSuccessSnackbar('Token FCM anda berhasil ditetapkan');
    } else {
      showErrorSnackbar('Terjadi kesalahan saat menetapkan token FCM');
    }
  }

  @override
  void onClose() {
    // Bersihkan resource jika ada
    super.onClose();
  }
}
