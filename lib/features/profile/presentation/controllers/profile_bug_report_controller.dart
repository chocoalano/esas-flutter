import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
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

    // Paints the messages when the form is on screen; the values are checked
    // again regardless, so the refusal does not depend on a mounted widget.
    bugReportFormKey.currentState?.validate();
    if (validateTitle(titleController.text) != null ||
        validateMessage(messageController.text) != null) {
      return;
    }

    if (isLoading.value) return;
    isLoading.value = true;

    try {
      await _repository.submitBugReport(
        title: titleController.text,
        message: messageController.text,
        platform: selectedPlatform.value,
        screenshot: pickedImage.value,
        idempotencyKey: _keyFor(_fingerprint()),
      );

      _attemptKey = null;
      _attemptFingerprint = null;
      showSuccessSnackbar('Laporan bug berhasil dikirim!');
      _clearForm();
    } on ApiException catch (error) {
      // A refusal ends the attempt; no answer does not — the report may have
      // been filed, and the retry must be recognisable as the same one.
      if (!_outcomeUnknown(error)) {
        _attemptKey = null;
        _attemptFingerprint = null;
      }
      showErrorSnackbar(error.firstFieldError ?? error.message);
    } finally {
      isLoading.value = false;
    }
  }

  /// One key per report, not per tap (PROF-08). It used to be minted inside
  /// the API call, so "Kirim" again after a timeout filed the report twice.
  String? _attemptKey;
  String? _attemptFingerprint;

  String _keyFor(String fingerprint) {
    if (_attemptKey == null || _attemptFingerprint != fingerprint) {
      _attemptKey = IdempotencyKey.mint();
      _attemptFingerprint = fingerprint;
    }
    return _attemptKey!;
  }

  String _fingerprint() => [
    titleController.text,
    messageController.text,
    selectedPlatform.value,
    pickedImage.value?.path ?? '',
  ].join('\u0000');

  /// Whether the report may have been filed although no answer said so — the
  /// same reading the leave form uses.
  static bool _outcomeUnknown(ApiException error) {
    final status = error.status;

    return status == null ||
        status >= 500 ||
        status == 429 ||
        error.code == 'idempotency_in_progress';
  }

  void _clearForm() {
    titleController.clear();
    messageController.clear();
    pickedImage.value = null;
    selectedPlatform.value = 'android';
  }
}
