import 'dart:async';
import 'dart:io';
import 'package:esas/app/data/Permit/leave_list.m.dart';
import 'package:esas/utils/helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/views/snackbar.dart'; // Pastikan jalur ini benar
import 'package:flutter/material.dart'; // Diperlukan untuk debugPrint

// Import model LeaveType untuk cek tipe argumen
import 'package:esas/app/data/Permit/leave_type.m.dart';

class PermitListController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  final ScrollController scrollController = ScrollController();

  final isLoading = false.obs;
  final isLoadMore = false.obs;
  final hasMore = true.obs;
  final page = 1.obs;
  final int pageSize = 10;

  final RxList<Permit> permits = <Permit>[].obs;
  final permitType = Rx<LeaveType?>(null);

  // Tambahkan observable untuk judul AppBar agar bisa diakses dan diperbarui oleh View
  final RxString appBarTitle = 'Daftar Perizinan'.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeArguments(); // Mengubah nama method agar lebih umum
    resetAndFetch();
    scrollController.addListener(_scrollListener);
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  void _scrollListener() {
    // Memastikan scrollController.position tidak null sebelum diakses
    if (scrollController.position.pixels ==
        scrollController.position.maxScrollExtent) {
      if (hasMore.value && !isLoadMore.value) {
        loadMorePermits();
      }
    }
  }

  // --- PERBAIKAN UTAMA DI SINI ---
  // Menangani berbagai tipe argumen yang mungkin masuk
  void _initializeArguments() {
    final dynamic args = Get.arguments;
    permitType.value = args;
    appBarTitle.value = permitType.value?.type ?? 'Daftar Perizinan';
  }
  // --- AKHIR PERBAIKAN UTAMA ---

  Future<void> resetAndFetch() async {
    page.value = 1;
    hasMore.value = true;
    permits.clear();
    // Panggil fetchPermits tanpa loadMore karena ini adalah reset awal
    await fetchPermits(loadMore: false);
  }

  Future<void> fetchPermits({bool loadMore = false}) async {
    if (loadMore) {
      if (!hasMore.value || isLoadMore.value) {
        if (kDebugMode && !hasMore.value) {
          debugPrint('PermitListController: No more data to load.');
        }
        if (kDebugMode && isLoadMore.value) {
          debugPrint('PermitListController: Already loading more data.');
        }
        return;
      }
      isLoadMore.value = true;
      page.value++;
    } else {
      isLoading.value = true;
    }
    final String url =
        '/hris-module/permits/list/${permitType.value?.id}?page=${page.value}&limit=$pageSize';

    if (kDebugMode) debugPrint('Fetching permits from URL: $url');

    try {
      final response = await _apiProvider.get(url);

      if (response.statusCode == 200) {
        // Pastikan 'data' ada dan merupakan List
        final List<dynamic>? responseData = response.body['data'];
        if (responseData != null) {
          final List<Permit> newItems = responseData
              .map((e) => Permit.fromJson(e as Map<String, dynamic>))
              .toList();

          if (loadMore) {
            permits.addAll(newItems);
          } else {
            permits.assignAll(newItems);
          }

          if (newItems.length < pageSize) {
            hasMore.value = false;
          } else {
            hasMore.value = true;
          }
        } else {
          // Jika 'data' null, anggap tidak ada lagi data
          hasMore.value = false;
          if (loadMore) {
            page.value--; // Kembalikan halaman jika tidak ada data baru
          }
          if (kDebugMode) {
            debugPrint('API response "data" field is null or empty.');
          }
        }
      } else {
        showApiError(response.statusCode, response.body);
        if (loadMore) {
          page.value--; // Kembalikan halaman jika terjadi error saat loadMore
        }
      }
    } on SocketException {
      showErrorSnackbar(
        'Tidak ada koneksi internet. Mohon periksa koneksi Anda.',
      );
      if (loadMore) page.value--;
    } on TimeoutException {
      showErrorSnackbar('Koneksi terlalu lama. Mohon coba lagi.');
      if (loadMore) page.value--;
    } on PlatformException catch (e) {
      showErrorSnackbar(e.message ?? 'Gagal mengambil data perizinan.');
      if (kDebugMode) debugPrint('PlatformException: ${e.message}');
      if (loadMore) page.value--;
    } catch (e) {
      print(e);
      if (kDebugMode) debugPrint('General Error in fetchPermits: $e');
      showErrorSnackbar(
        'Terjadi kesalahan yang tidak terduga saat mengambil data.',
      );
      if (loadMore) page.value--;
    } finally {
      if (loadMore) {
        isLoadMore.value = false;
      } else {
        isLoading.value = false;
      }
    }
  }

  void loadMorePermits() => fetchPermits(loadMore: true);
}
