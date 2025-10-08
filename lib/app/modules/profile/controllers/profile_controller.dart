import 'dart:io';
import 'package:esas/app/routes/app_pages.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/controllers/storage_keys.dart';

class ProfileController extends GetxController {
  final GetStorage _storage = GetStorage();
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  final RxString avatar = ''.obs;
  final RxString name = 'nama pengguna'.obs;
  final RxString jobTitle = 'jabatan pengguna'.obs;
  final RxString status = 'status pengguna'.obs;
  final Rx<DateTime> joined = DateTime.now().obs;

  final RxInt late = 0.obs;
  final RxInt attendance = 0.obs;
  final RxInt unlate = 0.obs;
  final RxDouble points = 0.0.obs;

  final RxBool isLoadingInitial = false.obs;
  final RxBool isUploading = false.obs;

  final Rxn<File> pickedImageFile = Rxn<File>();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    setupFromStorage();
    setupSummaryAbsen();
  }

  void setupFromStorage() {
    final user = _storage.read(StorageKeys.userJson) ?? {};

    avatar.value = user['avatar'] ?? '';
    name.value = user['name'] ?? 'nama pengguna';
    jobTitle.value =
        user['employee']?['job_position']?['name'] ?? 'jabatan pengguna';
    status.value = user['status'] ?? 'status pengguna';

    final signDateStr = user['employee']?['sign_date'];
    try {
      joined.value = signDateStr != null
          ? DateTime.parse(signDateStr)
          : DateTime.now();
    } catch (e) {
      debugPrint('Error parsing sign_date: $e');
      joined.value = DateTime.now();
    }
  }

  void updateUserName(String newName) {
    name.value = newName;
    final user = _storage.read(StorageKeys.userJson) ?? {};
    user['name'] = newName;
    _storage.write(StorageKeys.userJson, user);
  }

  Future<void> setupSummaryAbsen() async {
    try {
      final response = await _apiProvider.get(
        '/general-module/auth/summary-absen',
      );
      final resData = response.body as Map<String, dynamic>;

      points.value = _parseDouble(resData['persen_point']);
      late.value = _parseInt(resData['total_terlambat']);
      attendance.value = _parseInt(resData['total_absensi']);
      unlate.value = _parseInt(resData['total_normal']);

      debugPrint("Summary Absen Loaded: total_absensi = ${attendance.value}");
    } catch (e) {
      debugPrint("Error loading summary absen: $e");
    }
  }

  Future<void> pickImageFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        Get.snackbar('Informasi', 'Tidak ada gambar yang dipilih.');
        return;
      }

      pickedImageFile.value = File(image.path);
      await uploadProfilePicture(pickedImageFile.value!);
    } catch (e) {
      Get.snackbar('Error', 'Gagal memilih gambar: $e');
      debugPrint('ImagePicker error: $e');
    }
  }

  Future<void> uploadProfilePicture(File imageFile) async {
    if (isUploading.value) return;

    isUploading.value = true;
    try {
      final formData = FormData({
        'file': MultipartFile(
          imageFile,
          filename: imageFile.path.split('/').last,
        ),
      });

      final res = await _apiProvider.postFormData(
        '/general-module/auth',
        formData,
      );
      debugPrint("Upload response: ${res.body}");

      if (res.statusCode == 200 && res.body != null) {
        final data = res.body as Map<String, dynamic>;
        final newAvatar = data['avatar'] as String;

        avatar.value = newAvatar;

        final user = _storage.read(StorageKeys.userJson) ?? {};
        user['avatar'] = newAvatar;
        _storage.write(StorageKeys.userJson, user);
        _storage.write(StorageKeys.userAvatar, newAvatar);

        Get.snackbar('Sukses', 'Foto profil berhasil diunggah!');
      } else {
        Get.snackbar('Error', 'Upload gagal. Status: ${res.statusCode}');
      }
    } catch (e) {
      Get.snackbar('Error', 'Upload error: $e');
      debugPrint('Upload error: $e');
    } finally {
      isUploading.value = false;
      pickedImageFile.value = null;
    }
  }

  Future<void> logout() async {
    try {
      final res = await _apiProvider.get('/general-module/auth/logout');
      if (res.statusCode == 200) {
        Get.snackbar('Berhasil', 'Anda berhasil logout.');
        clearStorage();
        Get.offAllNamed(Routes.LOGIN);
      } else {
        Get.snackbar('Gagal', 'Anda gagal logout.');
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal memilih gambar: $e');
      debugPrint('logout error: $e');
    }
  }

  Future<void> clearStorage() async {
    await _storage.remove(StorageKeys.token);
    await _storage.remove(StorageKeys.tokenType);
    await _storage.remove(StorageKeys.userName);
    await _storage.remove(StorageKeys.userId);
    await _storage.remove(StorageKeys.userNip);
    await _storage.remove(StorageKeys.userPassword);
    await _storage.remove(StorageKeys.userJson);
    await _storage.remove(StorageKeys.userAvatar);

    if (kDebugMode) print('All authentication data cleared from storage.');
  }

  // Helpers
  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
