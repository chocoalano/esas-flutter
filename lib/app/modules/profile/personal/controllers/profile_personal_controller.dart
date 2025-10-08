import 'package:esas/app/data/Profile/user.m.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ProfilePersonalController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  Rx<User> userInfo = User().obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  @override
  void onInit() {
    super.onInit();
    setupSummaryAbsen();
  }

  Future<void> setupSummaryAbsen() async {
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

  String get formattedJoinedDate {
    if (userInfo.value.details?.datebirth != null) {
      return DateFormat(
        'dd MMMM yyyy',
      ).format(userInfo.value.details!.datebirth!);
    }
    return '-';
  }

  // Getter untuk alamat lengkap
  String get fullAddress {
    final address = userInfo.value.address;
    if (address == null) return '-';

    final parts = <String>[];
    if (address.citizenAddress != null && address.citizenAddress!.isNotEmpty) {
      parts.add(address.citizenAddress!);
    }
    if (address.city != null && address.city!.isNotEmpty) {
      parts.add(address.city!);
    }
    if (address.province != null && address.province!.isNotEmpty) {
      parts.add(address.province!);
    }
    return parts.join(', ').isEmpty ? '-' : parts.join(', ');
  }
}
