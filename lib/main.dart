import 'dart:io';

import 'package:esas/app/services/api_external_provider.dart';
import 'package:esas/utils/notification/firebase_messaging_services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
  await GetStorage.init();

  try {
    await Firebase.initializeApp();
    debugPrint("Firebase initialized.");
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  Get.put(BottomNavController(), permanent: true);
  Get.put(ThemeController(), permanent: true);
  Get.put(ApiProvider(), permanent: true);
  Get.put(ApiExternalProvider(), permanent: true);

  final notificationService = Get.put(NotificationService(), permanent: true);
  await notificationService.initialize();
  Get.put(FirebaseMessagingService(), permanent: true);

  final isDarkMode = Get.find<ThemeController>().isDarkMode;
  _setSystemUIOverlayStyle(isDarkMode);
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
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
