import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import 'routing/app_pages.dart';

/// The application widget.
///
/// Was `MyApp` in `main.dart`, beside the bootstrap, the dependency
/// registration and two unused dialogs. Nothing about it changes here except
/// where it lives and what it is called.
class EsasApp extends StatelessWidget {
  const EsasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ESAS',
        initialRoute: AppPages.initial,
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
