import 'dart:async';
import 'dart:io';

import 'package:esas/features/notification/data/services/notification_sync_service.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/utils/app_logger.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/auth/data/services/auth_api_service.dart';
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
  // Hanya id-nya. `debugPrint` TIDAK dihapus di build rilis, dan isi
  // notifikasi aplikasi HRIS menyebut gaji, cuti, dan absensi orang — mencetak
  // badan pesan berarti menuliskannya ke log perangkat selamanya.
  AppLogger.info('Background message received: ${message.messageId}');

  // Notification payloads are displayed by the OS in the background. Creating
  // another local notification here duplicates them and loses their data.
}

/// Minta izin notifikasi dan daftarkan token, bila push memang terpasang.
///
/// Dipanggil dari DUA tempat, dan keduanya berarti hal yang sama: baru saja ada
/// sesi. Dijaga [GetInstance.isRegistered] karena harness uji dan build tanpa
/// Firebase tidak mendaftarkan servicenya — dan masuk ke aplikasi tidak boleh
/// bergantung pada push.
Future<void> ensurePushRegisteredIfAvailable() async {
  if (Get.isRegistered<NotificationSyncService>()) {
    Get.find<NotificationSyncService>().onSessionReady();
  }
  if (!Get.isRegistered<FirebaseMessagingService>()) return;

  await Get.find<FirebaseMessagingService>().ensurePushRegistered();
}

class FirebaseMessagingService extends GetxService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late final NotificationService _notificationService;
  final AuthApiService _authApi = Get.find<AuthApiService>();
  final SessionRepository _session = Get.find<SessionRepository>();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _seenMessages = {};

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

  /// Pasang listener pesan. **Tidak meminta izin dan tidak mengambil token.**
  ///
  /// Keduanya menunggu sampai ada sesi; lihat [ensurePushRegistered]. Yang
  /// dipasang di sini hanya penerima pesan, dan itu aman dijalankan kapan pun:
  /// tanpa izin, tidak ada pesan yang datang, dan tidak ada dialog yang muncul.
  Future<void> _initializeFirebaseMessagingListeners() async {
    // 1. Menangani event FCM Token Refresh.
    //
    // Ini juga jaring pengaman iOS: ketika APNs belum menyerahkan tokennya pada
    // langkah 2, Firebase menerbitkan token FCM-nya beberapa saat kemudian dan
    // pendaftaran menyusul lewat jalur ini tanpa perlu membuka ulang aplikasi.
    _subscriptions.add(
      _firebaseMessaging.onTokenRefresh.listen(
        (newToken) {
          AppLogger.info('FCM token refreshed.');
          _fcmToken.value = newToken;
          setupToken(newToken);
        },
        onError: (Object err) {
          AppLogger.warning('FCM token refresh failed: $err');
        },
      ),
    );

    // 2. Mengatur handler pesan background global.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Menangani Pesan Foreground.
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((message) {
        final sync = Get.find<NotificationSyncService>();
        if (!sync.accepts(message.data)) return;
        final id = message.messageId;
        if (id != null && !_seenMessages.add(id)) return;
        if (_seenMessages.length > 100) {
          _seenMessages.remove(_seenMessages.first);
        }
        AppLogger.info('Foreground message received: ${message.messageId}');
        _notificationService.showNotification(
          message.notification?.title ?? "New Notification",
          message.notification?.body ?? "You have a new message",
          data: message.data,
        );
        unawaited(sync.received(message.data));
      }),
    );

    // 4. Menangani Pesan saat aplikasi dibuka dari keadaan terminated/background.
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        AppLogger.info('Notification opened the app: ${message.messageId}');
        _handleNotificationNavigation(message.data);
      }),
    );

    // 5. Mengambil pesan awal jika aplikasi diluncurkan dari keadaan terminated oleh notifikasi.
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      AppLogger.info(
        'App launched from a notification: ${initialMessage.messageId}',
      );
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  /// Minta izin notifikasi bila perlu, lalu pastikan token push terdaftar.
  ///
  /// **Idempoten, dan itu seluruh rancangannya.** Ia dipanggil setiap kali ada
  /// sesi — sesudah masuk, dan pada setiap pembukaan aplikasi yang sesinya
  /// dipulihkan — dan menjalankannya berkali-kali tidak menimbulkan efek
  /// samping: izin yang sudah diberikan tidak memunculkan dialog kedua, dan
  /// token yang sama didaftarkan ulang ke endpoint yang sama.
  ///
  /// Pengulangan itu yang menutup empat celah sekaligus, tanpa penjadwal dan
  /// tanpa polling:
  ///
  /// * **Izin ditolak lalu dinyalakan dari Setelan.** Tidak ada callback dari
  ///   sistem untuk ini. Pembukaan aplikasi berikutnya yang menemukannya.
  /// * **APNs belum terbit saat aplikasi dibuka.** iOS tidak bisa menerbitkan
  ///   token FCM sebelum APNs menyerahkan miliknya; percobaan berikutnya —
  ///   atau `onTokenRefresh` — yang menyelesaikannya.
  /// * **Token diperoleh sebelum ada sesi.** Pendaftaran ke server butuh
  ///   bearer; tanpa sesi `setupToken` menolak dengan sengaja, dan panggilan
  ///   sesudah masuk inilah yang mendaftarkannya.
  /// * **Perangkat berpindah pemilik.** Karyawan berikutnya yang masuk
  ///   mendaftarkan token yang sama atas namanya sendiri.
  ///
  /// Tidak pernah melempar: push adalah kapabilitas penunjang, dan tidak boleh
  /// menjadi alasan seseorang gagal masuk atau gagal membuka Beranda.
  Future<void> ensurePushRegistered() async {
    try {
      final NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            announcement: false,
            carPlay: false,
            criticalAlert: false,
            // Tidak memakai izin provisional: notifikasi senyap yang tidak
            // pernah diminta orangnya bukan strategi yang dipilih produk ini.
            provisional: false,
          );

      final AuthorizationStatus status = settings.authorizationStatus;

      AppLogger.info('Notification permission: ${status.name}.');

      if (status == AuthorizationStatus.denied) {
        // Ditolak bukan kegagalan. Aplikasi berjalan penuh tanpa notifikasi,
        // dan orangnya bisa menyalakannya kapan saja dari Setelan — pembukaan
        // berikutnya yang menemukannya.
        return;
      }

      await _acquireAndRegisterToken();
    } on Object catch (error) {
      AppLogger.warning('Push setup skipped: $error');
    }
  }

  /// Ambil token FCM perangkat ini, lalu daftarkan ke server.
  ///
  /// ## iOS pernah tidak pernah mendaftar sama sekali
  ///
  /// Versi sebelumnya bercabang begini:
  ///
  /// ```dart
  /// if (Platform.isIOS) {
  ///   final apns = await _firebaseMessaging.getAPNSToken();
  ///   debugPrint("APNs Token: $apns");   // diambil, dicetak, dibuang
  /// } else {
  ///   final token = await _firebaseMessaging.getToken();
  ///   setupToken(token);                 // hanya Android yang mendaftar
  /// }
  /// ```
  ///
  /// Cabang iOS mengambil token APNs, mencetaknya, lalu berhenti — `getToken()`
  /// tidak pernah dipanggil dan `setupToken` tidak pernah dijalankan. Sehingga
  /// **tidak ada satu pun iPhone yang pernah terdaftar di server**, terlepas
  /// dari benar atau tidaknya entitlement. Itu bug yang berdiri sendiri, dan
  /// tidak akan terlihat dari log simulator mana pun.
  ///
  /// ## APNs dulu, baru FCM — dan tidak menghalangi apa pun
  ///
  /// Di iOS, Firebase tidak bisa menerbitkan token FCM sebelum APNs menyerahkan
  /// miliknya. Menanyakannya terlalu awal menghasilkan `null`, dan itu keadaan
  /// NORMAL — bukan galat. Jadi di sini ia hanya berhenti dan menyerahkan
  /// urusannya ke `onTokenRefresh`; tidak ada yang dilempar, tidak ada yang
  /// ditunggu, dan tidak ada satu pun bagian aplikasi yang gagal berjalan
  /// karena push belum siap.
  Future<void> _acquireAndRegisterToken() async {
    try {
      if (Platform.isIOS) {
        final String? apns = await _firebaseMessaging.getAPNSToken();

        if (apns == null) {
          AppLogger.info(
            'APNs token not issued yet; FCM registration will follow on '
            'token refresh.',
          );
          return;
        }
      }

      final String? token = await _firebaseMessaging.getToken();

      if (token == null || token.isEmpty) {
        AppLogger.info('No FCM token available yet.');
        _fcmToken.value = '';
        return;
      }

      _fcmToken.value = token;
      await setupToken(token);
    } on Object catch (error) {
      // Push yang gagal disiapkan tidak boleh menjatuhkan peluncuran aplikasi.
      AppLogger.warning('Could not acquire a push token: $error');
    }
  }

  /// Helper method untuk menangani navigasi berdasarkan data notifikasi.
  /// Ini bisa diperluas untuk mem-parsing kunci spesifik dari data.
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    Get.find<NotificationSyncService>().open(data);
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

  /// Register this device's FCM token with the backend.
  ///
  /// Two things were wrong with how this used to run (HIGH-04).
  ///
  /// It fired from `main()`, before `SplashController` had restored or rejected
  /// a session — so on a fresh install and after every logout it posted to an
  /// authenticated endpoint with no token, got a 401, and then tried to show a
  /// snackbar from a point in the process where there is no `GetMaterialApp`,
  /// no overlay and no theme, because `runApp` had not been called.
  ///
  /// So it now does nothing without a session, and it reports rather than
  /// presents: infrastructure does not own the decision to show a snackbar
  /// (MED-03). The caller decides, and until Phase 3 gives `AuthRepository` a
  /// post-login hook to call, the caller is app start — which is correct for a
  /// returning user and correctly a no-op for everybody else.
  Future<bool> setupToken(String token) async {
    if (!_hasSession) {
      AppLogger.info(
        'Skipping FCM token registration: no session yet. '
        'It is retried on the next launch after signing in.',
      );
      return false;
    }

    try {
      // Platform ikut dikirim: kontraknya `{token, platform}`, dan tanpa itu
      // server tidak bisa memilih APNs atau FCM saat mengirim.
      await _authApi.setPushToken(
        token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      // Tokennya sendiri TIDAK pernah ikut dicatat. Ia identifier setingkat
      // kredensial: siapa pun yang memilikinya bisa dikirimi notifikasi atas
      // nama perangkat ini.
      AppLogger.info('Push token registered.');

      return true;
    } on ApiException catch (error) {
      AppLogger.warning(
        'FCM token registration refused with status ${error.status}.',
      );

      return false;
    }
  }

  /// Whether there is a session to register a token against.
  ///
  /// Asks `SessionRepository`, the single authority on it.
  bool get _hasSession => _session.isAuthenticated;

  @override
  void onClose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.onClose();
  }
}
