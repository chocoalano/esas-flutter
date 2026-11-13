import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import '../core/ui/controllers/bottom_nav_controller.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/app_update/presentation/app_update_gate.dart';
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
        title: 'Absensas',
        // No global textScaler clamp. Key layouts (AppDataRow, AppRecordField,
        // AnnouncementCarousel) already adapt individually when scale grows
        // beyond their breakpoints, so a blanket cap is not needed and would
        // prevent users from exercising their system accessibility settings.
        // AppUpdateGate covers every route when the Console makes an update
        // mandatory, and offers an optional one on top of it.
        builder: (context, child) => AppUpdateGate(child: child!),
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        unknownRoute: AppPages.unknownRoute,
        // The lit tab follows the route, however the route was reached
        // (UI-01).
        routingCallback: (routing) {
          final current = routing?.current;
          if (current != null && Get.isRegistered<BottomNavController>()) {
            Get.find<BottomNavController>().syncWith(current);
          }
        },
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
