// lib/app/modules/profile/controllers/profile_education_controller.dart

import 'package:esas/app/data/Profile/foeducation.m.dart'; // Make sure this defines FormalEducation
import 'package:esas/app/data/Profile/ineducation.m.dart'; // Make sure this defines InformalEducationModel
import 'package:esas/app/data/Profile/user.m.dart'; // Make sure this defines User and has correct parsing
import 'package:esas/app/services/api_provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Required for date formatting
import 'package:flutter/material.dart'; // For Colors in Get.snackbar

class ProfileEducationController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  final RxList<FormalEducation> formalEducations = <FormalEducation>[].obs;
  final RxList<InformalEducationModel> informalEducations =
      <InformalEducationModel>[].obs; // New: for informal education
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchEducationData(); // Renamed for clarity
  }

  Future<void> fetchEducationData() async {
    // Renamed method
    isLoading(true);
    errorMessage('');
    formalEducations.clear();
    informalEducations.clear(); // Clear informal education data too

    try {
      final response = await _apiProvider.get('/general-module/auth');

      if (response.statusCode == 200 && response.body != null) {
        final resData = response.body as Map<String, dynamic>;

        if (resData['user'] is Map<String, dynamic>) {
          final userData = resData['user'] as Map<String, dynamic>;
          final User user = User.fromJson(
            userData,
          ); // Parse the full User object

          debugPrint("+++++++ response user data ++++++++ : $userData");

          // Assign formal education data
          formalEducations.value = user.formalEducations ?? [];
          // Assign informal education data
          informalEducations.value =
              user.informalEducations ?? []; // Get informal education

          debugPrint(
            "Formal Educations Loaded: ${formalEducations.length} entries",
          );
          debugPrint(
            "Informal Educations Loaded: ${informalEducations.length} entries",
          );
        } else {
          errorMessage('Data pengguna tidak valid dalam respons API.');
          debugPrint(
            "API response 'user' key is missing or not a map: $resData",
          );
        }
      } else {
        errorMessage(
          'Gagal memuat data pendidikan: ${response.statusText ?? 'Unknown error'} (Status: ${response.statusCode ?? '-'})',
        );
      }
    } catch (e) {
      debugPrint("Error fetching education data: $e");
      errorMessage(
        'Terjadi kesalahan saat memuat data pendidikan: ${e.toString()}',
      );
      Get.snackbar(
        'Error',
        'Gagal memuat data pendidikan Anda.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMMM yyyy').format(date);
  }

  String formatEducationPeriod(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) return '-';
    String start = startDate != null
        ? DateFormat('yyyy').format(startDate)
        : '';
    String end = endDate != null ? DateFormat('yyyy').format(endDate) : '';

    if (start.isEmpty && end.isEmpty) return '-';
    if (start.isNotEmpty && end.isNotEmpty) return '$start - $end';
    if (start.isNotEmpty) return 'Sejak $start';
    return 'Hingga $end';
  }
}
