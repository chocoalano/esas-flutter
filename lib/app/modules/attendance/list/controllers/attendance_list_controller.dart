import 'package:esas/app/data/attendance/attendance.m.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/controllers/storage_keys.dart';
import 'package:esas/app/widgets/views/snackbar.dart';
import 'package:flutter/material.dart'; // Import for ScrollController
import 'package:get/get.dart';
import 'dart:async';

import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart'; // For Timer/Debouncing

class AttendanceListController extends GetxController {
  // Instance dari API Provider Anda
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final GetStorage _storage = GetStorage();
  // Reactive list untuk menyimpan data absensi
  final attendanceList =
      <Attendance>[].obs; // Ubah `dynamic` ke model `Attendance` Anda
  final isLoading = false.obs; // Status loading saat memuat data
  final isLoadMore = false.obs; // Status loading saat memuat halaman berikutnya
  final hasMore = true.obs; // Apakah masih ada data di server?

  int _currentPage = 1; // Halaman saat ini yang sedang dimuat
  final int _perPage = 10; // Jumlah item per halaman

  // ScrollController untuk mendeteksi posisi gulir
  late ScrollController scrollController;

  // Timer untuk debouncing scroll event
  Timer? _debounce;

  Rx<DateTime?> startDate = Rx<DateTime?>(null);
  Rx<DateTime?> endDate = Rx<DateTime?>(null);

  @override
  void onInit() {
    super.onInit();
    scrollController = ScrollController();
    scrollController.addListener(
      _scrollListener,
    ); // Tambahkan listener ke scroll controller

    // Panggil pemuatan data awal
    fetchAttendance();
  }

  @override
  void onClose() {
    scrollController.dispose(); // Pastikan scrollController dibuang
    _debounce?.cancel(); // Batalkan timer jika ada
    super.onClose();
  }

  /// Listener untuk mendeteksi kapan user mencapai akhir daftar
  void _scrollListener() {
    if (scrollController.position.pixels ==
        scrollController.position.maxScrollExtent) {
      // User telah mencapai akhir daftar
      _loadMoreDebounced();
    }
  }

  /// Debounce panggilan loadMore untuk mencegah terlalu sering memuat
  void _loadMoreDebounced() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (hasMore.value && !isLoading.value && !isLoadMore.value) {
        _currentPage++;
        fetchAttendance(isLoadMore: true);
      }
    });
  }

  /// Memuat data absensi dari API
  /// [isLoadMore] true jika ini adalah panggilan untuk memuat halaman berikutnya
  Future<void> fetchAttendance({bool isLoadMore = false}) async {
    if (isLoading.value || this.isLoadMore.value) {
      return; // Mencegah multiple request
    }

    if (isLoadMore) {
      this.isLoadMore.value = true;
    } else {
      isLoading.value = true; // Set loading state untuk pemuatan awal
      _currentPage = 1; // Reset halaman ke 1 untuk pemuatan awal
      hasMore.value = true; // Reset hasMore
      attendanceList.clear(); // Bersihkan daftar untuk pemuatan awal
    }

    try {
      final userId = _storage.read(StorageKeys.userId);
      // Panggil API Anda. Sesuaikan endpoint dan parameter.
      final query = {
        'page': _currentPage.toString(),
        'limit': _perPage.toString(),
        'search[user_id]': userId.toString(),
      };

      if (startDate.value != null && endDate.value != null) {
        final dateFormat = DateFormat('yyyy-MM-dd');
        query['search[start]'] = dateFormat.format(startDate.value!);
        query['search[end]'] = dateFormat.format(endDate.value!);
      }
      final response = await _apiProvider.get(
        '/hris-module/user-attendances', // Ganti dengan endpoint API Anda
        query: query,
      );
      if (response.statusCode == 200) {
        final List<dynamic> rawData = response.body['data'];
        if (rawData.isNotEmpty) {
          final newAttendance = rawData
              .map((json) => Attendance.fromJson(json))
              .toList();
          attendanceList.addAll(
            newAttendance,
          ); // Tambahkan data baru ke daftar yang sudah ada
          hasMore.value = newAttendance.length == _perPage; // Perbarui hasMore
        } else {
          hasMore.value = false; // Tidak ada lagi data yang bisa dimuat
        }
      } else {
        debugPrint(response.body);
        showErrorSnackbar("Gagal memuat data absensi: ${response.statusText}");
        hasMore.value =
            false; // Asumsikan tidak ada data lagi jika terjadi error
      }
    } catch (e) {
      showErrorSnackbar("Terjadi kesalahan: $e");
      debugPrint('Error fetching attendance: $e');
      hasMore.value = false;
    } finally {
      isLoading.value = false;
      this.isLoadMore.value = false;
    }
  }

  /// Metode untuk refresh data (misalnya, ditarik dari atas - pull-to-refresh)
  Future<void> refreshAttendance() async {
    attendanceList.clear(); // Bersihkan daftar
    _currentPage = 1; // Reset halaman
    hasMore.value = true; // Reset hasMore
    await fetchAttendance(); // Muat data dari awal
  }

  // Metode placeholder jika Anda ingin memperbarui `count`
  void increment() => _currentPage++;
}
