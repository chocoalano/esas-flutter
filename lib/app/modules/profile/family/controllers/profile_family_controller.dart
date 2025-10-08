import 'package:esas/app/data/Profile/user.m.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class ProfileFamilyController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  Rx<User> userInfo = User().obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  @override
  void onInit() {
    super.onInit();
    setupProfile();
  }

  @override
  void onReady() {
    super.onReady();
    setupProfile();
  }

  Future<void> setupProfile() async {
    isLoading.value = true;
    try {
      final response = await _apiProvider.get('/general-module/auth');
      final resData = response.body as Map<String, dynamic>;
      userInfo.value = User.fromJson(resData['user']);
      debugPrint("Info profile Loaded: total_absensi = $resData");
    } catch (e) {
      debugPrint("Error Info profile: $e");
      errorMessage('Data pengguna tidak ditemukan.');
    } finally {
      isLoading.value = false;
    }
  }
}
