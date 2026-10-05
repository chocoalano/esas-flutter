import 'package:get/get.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/json_parsers.dart';
import '../../data/models/announcement.dart';
import '../../data/repositories/home_repository.dart';

class AnnouncementDetailController extends GetxController {
  AnnouncementDetailController({required HomeRepository repository})
    : _repository = repository;

  final HomeRepository _repository;

  final Rx<Announcement?> detail = Rx<Announcement?>(null);
  final isLoading = false.obs;

  int? _announcementId;

  int get announcementId => _announcementId ?? -1;

  @override
  void onInit() {
    super.onInit();

    // `asInt` rather than `is int`: the id arrives from a route argument and,
    // when a notification tap opens this screen, from an FCM payload — where
    // every value is a string.
    _announcementId = asInt(Get.arguments);

    if (_announcementId == null) {
      showErrorSnackbar('Terjadi kesalahan karena ID tidak dikirim');
      return;
    }

    loadDetail();
  }

  Future<void> loadDetail() async {
    final id = _announcementId;

    if (id == null) {
      return;
    }

    isLoading.value = true;

    try {
      detail.value = await _repository.announcement(id);
    } on ApiException catch (error) {
      detail.value = null;
      showErrorSnackbar('Gagal memuat detail pengumuman: ${error.message}');
    } finally {
      isLoading.value = false;
    }
  }
}
