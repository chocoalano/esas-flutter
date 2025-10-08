import 'package:esas/app/data/announcement/list.m.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/views/snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class AnnouncementDetailController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  late final int announcementId;
  final Rx<Announcement?> detail = Rx<Announcement?>(null);
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments;
    if (args is int) {
      announcementId = args;
      loadDetail();
    } else {
      announcementId = -1;
      showErrorSnackbar("Terjadi kesalahan karena ID tidak dikirim");
    }
  }

  Future<void> loadDetail() async {
    if (announcementId <= 0) return;

    isLoading.value = true;
    final String url = '/general-module/announcements/$announcementId';
    debugPrint('Fetching announcement from URL: $url');

    try {
      final response = await _apiProvider.get(url);
      if (response.statusCode == 200 && response.body != null) {
        final data = response.body;
        detail.value = Announcement.fromJson(data);
      } else {
        showErrorSnackbar("Gagal memuat detail pengumuman.");
        detail.value = null;
      }
    } catch (e) {
      showErrorSnackbar("Terjadi kesalahan: ${e.toString()}");
      detail.value = null;
    } finally {
      isLoading.value = false;
    }
  }
}
