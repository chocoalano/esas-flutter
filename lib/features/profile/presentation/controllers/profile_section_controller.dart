import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/user.dart';
import '../../data/repositories/profile_repository.dart';

/// Shared behaviour for the profile tabs.
///
/// Five sub-controllers — personal, worked, family, education, experience —
/// were byte-for-byte identical apart from their getters: same three observable
/// fields, same `GET /general-module/auth`, same try/catch, same debug prints.
/// Walking the tabs therefore made five identical network calls.
///
/// They now share this base and one cached read on [ProfileRepository].
abstract class ProfileSectionController extends GetxController {
  ProfileSectionController({required ProfileRepository repository})
    : _repository = repository;

  final ProfileRepository _repository;

  final Rx<User> userInfo = User().obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile({bool refresh = false}) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      userInfo.value = await _repository.currentUser(refresh: refresh);
      onProfileLoaded(userInfo.value);
    } on ApiException catch (error) {
      errorMessage.value = error.isTransportFailure
          ? 'Tidak dapat terhubung ke server.'
          : 'Data pengguna tidak ditemukan.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Hook for a tab that derives lists from the record.
  void onProfileLoaded(User user) {}

  /// The names the tabs called this by before they shared a base. Kept so the
  /// views' pull-to-refresh and retry buttons keep working unchanged.
  Future<void> setupProfile() => loadProfile(refresh: true);

  Future<void> setupSummaryAbsen() => loadProfile(refresh: true);
}
