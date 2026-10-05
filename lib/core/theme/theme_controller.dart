import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart'; // Import GetStorage

import 'system_ui_style.dart';

class ThemeController extends GetxController {
  // Kunci untuk menyimpan preferensi tema di GetStorage
  static const String _themeKey = 'isDarkMode';

  // Instance GetStorage
  final GetStorage _box = GetStorage();

  // Observable untuk status mode gelap
  // Inisialisasi dengan nilai yang disimpan, atau default ke false jika belum ada
  late RxBool _isDarkMode;

  // Getter untuk mengakses nilai mode gelap
  bool get isDarkMode => _isDarkMode.value;

  @override
  void onInit() {
    super.onInit();
    // Baca nilai tema dari GetStorage saat controller diinisialisasi
    // Jika tidak ada nilai yang tersimpan, default ke false (light mode)
    // Atau Anda bisa menggunakan Get.theme.brightness == Brightness.dark
    // untuk mengikuti tema sistem secara default jika belum ada preferensi.
    _isDarkMode = (_box.read<bool>(_themeKey) ?? false).obs;
    // Terapkan tema saat aplikasi dimulai berdasarkan nilai yang disimpan
    Get.changeThemeMode(_isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
    applySystemUiOverlayStyle(isDarkMode: _isDarkMode.value);
  }

  /// Fungsi untuk mengubah tema (light/dark)
  void toggleTheme() {
    // Balikkan nilai mode gelap
    _isDarkMode.value = !_isDarkMode.value;

    // Simpan nilai baru ke GetStorage
    _box.write(_themeKey, _isDarkMode.value);

    // Ubah tema aplikasi secara langsung
    Get.changeThemeMode(_isDarkMode.value ? ThemeMode.dark : ThemeMode.light);

    // Bilah status dan bilah navigasi sistem ikut berganti. Sebelumnya
    // keduanya hanya diwarnai sekali saat aplikasi dijalankan, jadi setelah
    // pengguna berpindah ke mode gelap, dasar bilah navigasi tetap putih
    // sampai aplikasi ditutup dan dibuka lagi.
    applySystemUiOverlayStyle(isDarkMode: _isDarkMode.value);

    // Tidak ada snackbar di sini. Sebelumnya setiap pergantian tema memunculkan
    // notifikasi "Mode Gelap Aktif" berwarna abu-abu yang ditulis di luar tema,
    // sehingga satu-satunya elemen di layar yang tidak ikut berganti warna
    // justru adalah pemberitahuan tentang pergantian warna. Seluruh layar sudah
    // berubah — itu umpan balik yang paling jelas yang bisa diberikan.
  }
}
