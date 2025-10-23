// Semua import harus di bagian paling atas file
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:esas/app/services/api_external_provider.dart';
import 'package:esas/utils/notification/firebase_messaging_services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app/services/api_provider.dart';
import 'app/widgets/controllers/bottom_nav_controller.dart';
import 'app/widgets/controllers/theme_controller.dart';
import 'utils/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'utils/my_http_overrides.dart';
import 'utils/notification/notification_services.dart';

void _setSystemUIOverlayStyle(bool isDarkMode) {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDarkMode
          ? AppTheme.darkTheme.scaffoldBackgroundColor
          : AppTheme.lightTheme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: isDarkMode
          ? Brightness.dark
          : Brightness.light,
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage
  await GetStorage.init();

  // Small delay to allow native side to be ready (optional)
  await Future.delayed(const Duration(milliseconds: 200));

  // --- App Tracking Transparency (iOS only) ---
  if (Platform.isIOS) {
    try {
      // 1. Dapatkan status pelacakan saat ini
      final TrackingStatus status =
          await AppTrackingTransparency.trackingAuthorizationStatus;

      // 2. Hanya meminta otorisasi jika statusnya 'notDetermined'
      if (status == TrackingStatus.notDetermined) {
        // PENTING: Anda harus menampilkan dialog penjelasan kustom (custom explainer dialog)
        // SEBELUM memanggil requestTrackingAuthorization.
        // Dialog ini harus menjelaskan MENGAPA Anda membutuhkan izin tersebut.
        debugPrint('ATT status: Not Determined. Showing explainer...');

        // --- GANTI dengan logika untuk menampilkan Dialog Explainer kustom Anda ---
        await showCustomExplainerDialog();
        // ----------------------------------------------------------------------

        final TrackingStatus newStatus =
            await AppTrackingTransparency.requestTrackingAuthorization();

        debugPrint('ATT permission granted/denied: $newStatus');

        // JANGAN mengalihkan pengguna ke Pengaturan di sini jika statusnya Denied (newStatus == TrackingStatus.denied)
        // Tindakan ini melanggar pedoman.
      } else if (status == TrackingStatus.denied) {
        // Statusnya 'Denied' (ditolak) atau 'restricted'
        debugPrint('ATT status: Denied/Restricted. Respecting user\'s choice.');

        // JIKA pengguna mencoba menggunakan fitur yang MEMBUTUHKAN izin ATT
        // (misalnya, menampilkan iklan yang dipersonalisasi), Anda DAPAT
        // menampilkan notifikasi informatif.
        // Opsi: Berikan notifikasi di dalam aplikasi dengan opsi menuju Pengaturan,
        // BUKAN mengarahkan secara paksa.
        showInAppNotification(
          'Fitur personalisasi iklan tidak tersedia tanpa izin pelacakan. Anda dapat mengaktifkannya di Pengaturan.',
          () =>
              openAppSettings(), // Hanya panggil openAppSettings jika pengguna mengetuk tombol
        );
      }

      // 3. Mendapatkan IDFA (opsional, mungkin kosong jika tidak diizinkan)
      try {
        final String uuid =
            await AppTrackingTransparency.getAdvertisingIdentifier();
        debugPrint('Advertising ID (IDFA): $uuid');
      } catch (e) {
        debugPrint('Could not get advertising identifier: $e');
      }
    } catch (e) {
      debugPrint('AppTrackingTransparency error during handling: $e');
    }
  }

  // --- Initialize Firebase and services ---
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized.');
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Register singletons
  Get.put(BottomNavController(), permanent: true);
  Get.put(ThemeController(), permanent: true);
  Get.put(ApiProvider(), permanent: true);
  Get.put(ApiExternalProvider(), permanent: true);

  final notificationService = Get.put(NotificationService(), permanent: true);
  await notificationService.initialize();
  Get.put(FirebaseMessagingService(), permanent: true);

  // Apply system UI style based on saved theme
  final isDarkMode = Get.find<ThemeController>().isDarkMode;
  _setSystemUIOverlayStyle(isDarkMode);
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

/// Menampilkan notifikasi di dalam aplikasi dengan tombol menuju pengaturan (untuk ATT denied)
void showInAppNotification(String message, Future<bool> Function() onPressed) {
  Get.dialog(
    AlertDialog(
      title: const Text('Izin Pelacakan Diperlukan'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () async {
            await onPressed();
            Get.back();
          },
          child: const Text('Buka Pengaturan'),
        ),
        TextButton(onPressed: () => Get.back(), child: const Text('Tutup')),
      ],
    ),
    barrierDismissible: false,
  );
}

Future<void> showCustomExplainerDialog() async {
  // Gunakan navigatorKey agar bisa dipanggil dari main()
  final navigator = Get.key.currentState;
  if (navigator == null) {
    // Fallback jika navigator belum siap, tampilkan dialog sederhana
    return showDialog(
      context:
          Get.context ?? (throw Exception('No context for explainer dialog')),
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Izin Pelacakan'),
        content: const Text(
          'Aplikasi ini membutuhkan izin pelacakan untuk meningkatkan pengalaman Anda, menampilkan konten yang relevan, dan mendukung fitur personalisasi. Data yang dikumpulkan akan digunakan sesuai kebijakan privasi kami.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  } else {
    // Jika navigator tersedia, gunakan Get.dialog agar konsisten dengan GetX
    return Get.dialog(
      AlertDialog(
        title: const Text('Izin Pelacakan'),
        content: const Text(
          'Aplikasi ini membutuhkan izin pelacakan untuk meningkatkan pengalaman Anda, menampilkan konten yang relevan, dan mendukung fitur personalisasi. Data yang dikumpulkan akan digunakan sesuai kebijakan privasi kami.',
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: "ESAS",
        initialRoute: AppPages.INITIAL,
        getPages: AppPages.routes,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.isDarkMode
            ? ThemeMode.dark
            : ThemeMode.light,
        locale: const Locale('id', 'ID'),
        fallbackLocale: const Locale('id', 'ID'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('id', 'ID')],
      ),
    );
  }
}
