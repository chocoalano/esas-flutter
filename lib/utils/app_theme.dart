import 'package:flutter/material.dart';

class AppTheme {
  // ThemeData untuk mode terang
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: false,
    // Light theme specific colors
    scaffoldBackgroundColor: const Color(0xFFF0F2F5),
    colorScheme: const ColorScheme.light(
      primary: Colors.green,
      primaryContainer: Colors.lightBlueAccent,
      onPrimary: Colors.white,
      secondary: Colors.teal,
      secondaryContainer: Colors.tealAccent,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black87,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    // Light theme text styles
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
      bodySmall: TextStyle(fontSize: 12, color: Colors.black54),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
      labelMedium: TextStyle(fontSize: 12, color: Colors.black87),
      labelSmall: TextStyle(fontSize: 11, color: Colors.black54),
    ),
    // Light theme app bar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    // Light theme floating action button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    ),
    // Light theme input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade700),
      hintStyle: TextStyle(color: Colors.grey.shade500),
    ),
    // Light theme elevated button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    // Light theme text button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.green),
    ),
    // Light theme outlined button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.green,
        side: const BorderSide(color: Colors.green),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    // Light theme bottom navigation bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
  );

  // ThemeData untuk mode gelap
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: false, // Use Material 3 for dark theme as well
    // Dark theme specific colors
    primaryColor: const Color(0xff001e04),
    scaffoldBackgroundColor: const Color(0xff001e04),
    colorScheme: const ColorScheme.dark(
      primary: Colors.green,
      primaryContainer: Colors.greenAccent,
      onPrimary: Colors.white,
      secondary: Colors.tealAccent,
      secondaryContainer: Colors.teal,
      onSecondary: Colors.black,
      surface: Color(0xff002a06),
      onSurface: Colors.white70,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    // Dark theme text styles
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.white),
      bodySmall: TextStyle(fontSize: 12, color: Colors.white70),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      labelMedium: TextStyle(fontSize: 12, color: Colors.white),
      labelSmall: TextStyle(fontSize: 11, color: Colors.white70),
    ),
    // Dark theme app bar
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xff002a06),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    // Dark theme floating action button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor:
          Colors.green, // You might want to adjust this for dark mode
      foregroundColor: Colors.white,
    ),
    // Dark theme input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xff021e00), // Darker fill color for dark mode
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade300), // Lighter label text
      hintStyle: TextStyle(color: Colors.grey.shade500),
    ),
    // Dark theme elevated button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    // Dark theme text button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.greenAccent,
      ), // Adjusted for dark mode
    ),
    // Dark theme outlined button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.greenAccent, // Adjusted for dark mode
        side: const BorderSide(
          color: Colors.greenAccent,
        ), // Adjusted for dark mode
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    // Dark theme bottom navigation bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Colors.greenAccent, // Adjusted for dark mode
      unselectedItemColor: Colors.white,
      backgroundColor: Color(0xff002a06), // Darker background
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
