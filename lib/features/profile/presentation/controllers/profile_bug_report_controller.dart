import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/repositories/profile_repository.dart';

class ProfileBugReportController extends GetxController {
  ProfileBugReportController({
    required ProfileRepository repository,
    ImagePicker? imagePicker,
  }) : _repository = repository,
       _imagePicker = imagePicker ?? ImagePicker();

  final ProfileRepository _repository;
  final ImagePicker _imagePicker;

  final GlobalKey<FormState> bugReportFormKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  final RxString selectedPlatform = 'android'.obs;
  final RxBool status = true.obs;
  final RxBool isLoading = false.obs;
  final Rx<File?> pickedImage = Rx<File?>(null);

  final List<String> platforms = const ['web', 'android', 'ios'];

  @override
  void onClose() {
    titleController.dispose();
    messageController.dispose();
    super.onClose();
  }

  void onPlatformChanged(String? value) {
    if (value != null) {
      selectedPlatform.value = value;
    }
  }

  void onStatusChanged(bool? value) {
    if (value != null) {
      status.value = value;
    }
  }

  void removePickedImage() => pickedImage.value = null;

  Future<void> pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        pickedImage.value = File(image.path);
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Image picker failed',
        error: error,
        stackTrace: stackTrace,
      );
      showErrorSnackbar('Gagal memilih gambar.');
    }
  }

  String? validateTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Judul laporan tidak boleh kosong.';
    }

    if (value.length > 255) {
      return 'Judul tidak boleh lebih dari 255 karakter.';
    }

    return null;
  }

  String? validateMessage(String? value) {
    if (value == null || value.isEmpty) {
      return 'Pesan laporan tidak boleh kosong.';
    }

    return null;
  }

  String? validateImageRequired(File? value) =>
      value == null ? 'Gambar harus dilampirkan.' : null;

  Future<void> submitBugReport() async {
    final imageError = validateImageRequired(pickedImage.value);

    if (imageError != null) {
      showErrorSnackbar(imageError, title: 'Validasi Gambar');
      return;
    }

    if (!(bugReportFormKey.currentState?.validate() ?? false)) {
      return;
    }

    isLoading.value = true;

    try {
      await _repository.submitBugReport(
        title: titleController.text,
        message: messageController.text,
        platform: selectedPlatform.value,
        screenshot: pickedImage.value,
      );

      showSuccessSnackbar('Laporan bug berhasil dikirim!');
      _clearForm();
    } on ApiException catch (error) {
      showErrorSnackbar(error.firstFieldError ?? error.message);
    } finally {
      isLoading.value = false;
    }
  }

  void _clearForm() {
    titleController.clear();
    messageController.clear();
    pickedImage.value = null;
    selectedPlatform.value = 'android';
    status.value = true;
  }
}
