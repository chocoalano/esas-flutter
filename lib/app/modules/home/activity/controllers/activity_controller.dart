import 'dart:async';
import 'dart:io';

import 'package:esas/app/data/activity/log.m.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/views/snackbar.dart';
import 'package:esas/utils/helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ActivityController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final ScrollController scrollController = ScrollController();

  final isLoading = false.obs;
  final isLoadMore = false.obs;
  final hasMore = true.obs;
  final page = 1.obs;
  final int pageSize = 10;

  final RxList<ActivityLog> lists = <ActivityLog>[].obs;

  @override
  void onInit() {
    super.onInit();
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
        loadMoreApi();
      }
    }
  }

  Future<void> resetAndFetch() async {
    page.value = 1;
    hasMore.value = true;
    // Panggil fetchPermits tanpa loadMore karena ini adalah reset awal
    await fetchApi(loadMore: false);
  }

  void loadMoreApi() => fetchApi(loadMore: true);

  Future<void> fetchApi({bool loadMore = false}) async {
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
    final String url = '/general-module/auth/activity';
    try {
      final response = await _apiProvider.get(url);
      if (response.statusCode == 200) {
        // Pastikan 'data' ada dan merupakan List
        final List<dynamic>? responseData = response.body;

        if (responseData != null) {
          final List<ActivityLog> newItems = responseData
              .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
              .toList();

          if (loadMore) {
            lists.addAll(newItems);
          } else {
            lists.assignAll(newItems);
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
}
