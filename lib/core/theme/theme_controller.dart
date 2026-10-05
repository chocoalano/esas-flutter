import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart'; // Import GetStorage

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
  }

  /// Fungsi untuk mengubah tema (light/dark)
  void toggleTheme() {
    // Balikkan nilai mode gelap
    _isDarkMode.value = !_isDarkMode.value;

    // Simpan nilai baru ke GetStorage
    _box.write(_themeKey, _isDarkMode.value);

    // Ubah tema aplikasi secara langsung
    Get.changeThemeMode(_isDarkMode.value ? ThemeMode.dark : ThemeMode.light);

    // Opsional: Tampilkan snackbar untuk konfirmasi perubahan tema
    Get.snackbar(
      'Tema Berubah',
      _isDarkMode.value ? 'Mode Gelap Aktif' : 'Mode Terang Aktif',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: Get.isDarkMode
          ? Colors.grey.shade800
          : Colors.grey.shade200,
      colorText: Get.isDarkMode ? Colors.white : Colors.black,
    );
  }
}
