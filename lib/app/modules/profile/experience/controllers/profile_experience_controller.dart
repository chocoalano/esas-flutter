import 'package:esas/app/data/Profile/user.m.dart'; // Pastikan ini mendefinisikan User
import 'package:esas/app/data/Profile/workexp.m.dart'; // Pastikan ini mendefinisikan WorkExperienceModel
import 'package:esas/app/services/api_provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Required for date formatting
import 'package:flutter/material.dart'; // For Colors in Get.snackbar

class ProfileExperienceController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  final RxList<WorkExperienceModel> workExperiences = // Renamed for clarity
      <WorkExperienceModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchWorkExperienceData(); // Corrected method name
  }

  Future<void> fetchWorkExperienceData() async {
    // Corrected method name
    isLoading(true);
    errorMessage('');
    workExperiences.clear(); // Clear existing data before fetching

    try {
      final response = await _apiProvider.get('/general-module/auth');

      if (response.statusCode == 200 && response.body != null) {
        final resData = response.body as Map<String, dynamic>;

        if (resData['user'] is Map<String, dynamic>) {
          final userData = resData['user'] as Map<String, dynamic>;
          final User user = User.fromJson(
            userData,
          ); // Parse the full User object

          debugPrint(
            "+++++++ response user data for work experience ++++++++ : $userData",
          );

          // Assign work experience data
          workExperiences.value = user.workExperiences ?? []; // Assign once

          debugPrint(
            "Work Experiences Loaded: ${workExperiences.length} entries",
          );
        } else {
          errorMessage('Data pengguna tidak valid dalam respons API.');
          debugPrint(
            "API response 'user' key is missing or not a map: $resData",
          );
        }
      } else {
        errorMessage(
          'Gagal memuat data pengalaman kerja: ${response.statusText ?? 'Unknown error'} (Status: ${response.statusCode ?? '-'})',
        );
      }
    } catch (e) {
      debugPrint("Error fetching work experience data: $e");
      errorMessage(
        'Terjadi kesalahan saat memuat data pengalaman kerja: ${e.toString()}',
      );
      Get.snackbar(
        'Error',
        'Gagal memuat data pengalaman kerja Anda.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  // Helper method for formatting work period
  String formatWorkPeriod(DateTime? startDate, DateTime? finishDate) {
    if (startDate == null && finishDate == null) return '-';
    String start = startDate != null
        ? DateFormat('dd MMM yyyy').format(startDate)
        : '';
    String finish = finishDate != null
        ? DateFormat('dd MMM yyyy').format(finishDate)
        : 'Sekarang'; // "Sekarang" jika finish null

    if (start.isEmpty && finish.isEmpty) return '-';
    if (start.isNotEmpty && finish.isNotEmpty) return '$start - $finish';
    if (start.isNotEmpty) return 'Sejak $start'; // If only start date
    return 'Hingga $finish'; // If only finish date (less common)
  }

  // Helper method for formatting certification status
  String formatCertificationStatus(bool? certification) {
    if (certification == null) return '-';
    return certification ? 'Ya' : 'Tidak';
  }
}
