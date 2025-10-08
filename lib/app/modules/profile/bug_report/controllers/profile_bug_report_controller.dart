import 'dart:io'; // Required for File
import 'dart:convert'; // Required for json.decode

import 'package:esas/app/modules/profile/profile_pages.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart'; // Required for GlobalKey, TextEditingController, Color
import 'package:image_picker/image_picker.dart'; // Required for ImagePicker, XFile

import 'package:esas/app/services/api_provider.dart'; // Assuming this path is correct

class ProfileBugReportController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  final GlobalKey<FormState> bugReportFormKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  final RxString selectedPlatform = 'android'.obs; // Default platform
  final RxBool status = true.obs; // Default status (true = active bug)

  final RxBool isLoading = false.obs;

  final List<String> platforms = ['web', 'android', 'ios'];

  final Rx<File?> pickedImage = Rx<File?>(
    null,
  ); // Stores the selected image file

  @override
  void onClose() {
    titleController.dispose();
    messageController.dispose();
    super.onClose();
  }

  /// Updates the selected platform for the bug report.
  void onPlatformChanged(String? newValue) {
    if (newValue != null) {
      selectedPlatform.value = newValue;
    }
  }

  /// Updates the status of the bug (active/inactive).
  void onStatusChanged(bool? newValue) {
    if (newValue != null) {
      status.value = newValue;
    }
  }

  /// Opens the image picker to select an image from the gallery.
  /// Includes client-side size validation (max: 1MB as per rules).
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final File selectedFile = File(image.path);
      final int fileSizeInBytes = await selectedFile.length();
      final double fileSizeInKB = fileSizeInBytes / 1024;

      // Validate image size against the backend rule (max:1048KB = 1MB)
      if (fileSizeInKB > 1048) {
        _showSnackbar(
          'Ukuran Gambar Terlalu Besar',
          'Ukuran gambar maksimal adalah 1MB.',
          isError: true,
        );
        pickedImage.value = null; // Clear any previously picked large image
        return;
      }

      pickedImage.value = selectedFile;
      _showSnackbar(
        'Gambar Terpilih',
        'Gambar berhasil dilampirkan.',
        isSuccess: true,
      );
    } else {
      _showSnackbar(
        'Peringatan',
        'Pemilihan gambar dibatalkan atau tidak ada gambar dipilih.',
      );
    }
  }

  /// Removes the currently selected image.
  void removePickedImage() {
    pickedImage.value = null;
    _showSnackbar('Gambar Dihapus', 'Lampiran gambar telah dihapus.');
  }

  // --- Form Validation Methods ---

  /// Validates the title input field.
  String? validateTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Judul laporan tidak boleh kosong.';
    }
    if (value.length > 255) {
      return 'Judul tidak boleh lebih dari 255 karakter.';
    }
    return null;
  }

  /// Validates the message input field.
  String? validateMessage(String? value) {
    if (value == null || value.isEmpty) {
      return 'Pesan laporan tidak boleh kosong.';
    }
    return null;
  }

  /// Validates that an image has been picked (since it's 'required').
  String? validateImageRequired(File? value) {
    if (value == null) {
      return 'Gambar harus dilampirkan.';
    }
    return null;
  }

  /// Submits the bug report form to the API using GetConnect's FormData.
  Future<void> submitBugReport() async {
    // Manually validate the image field (since it's not a TextFormField)
    final String? imageValidationError = validateImageRequired(
      pickedImage.value,
    );
    if (imageValidationError != null) {
      _showSnackbar('Validasi Gambar', imageValidationError, isError: true);
      return; // Stop if image validation fails
    }

    // Validate all other form fields
    if (!bugReportFormKey.currentState!.validate()) {
      return; // Stop if form validation fails
    }

    isLoading(true); // Activate loading indicator

    try {
      // Prepare the data fields for FormData
      final Map<String, dynamic> dataFields = {
        'title': titleController.text,
        'message': messageController.text,
        'platform': selectedPlatform.value,
        'status': status.value ? 1 : 0, // Send as integer (0 or 1)
      };

      // Create GetX's FormData.
      // Append text fields and the image file.
      // IMPORTANT: The field name for the image must match your backend rule ('image').
      // Based on your initial rules: 'image' => ['required', 'image', 'mimes:jpeg,png,jpg,webp', 'max:1048']
      final form = FormData({
        ...dataFields, // Spread operator to add all text fields
        'image': MultipartFile(
          // Changed key from 'file' to 'image' to match rule
          pickedImage.value!, // Use the validated, non-null pickedImageFile
          filename: pickedImage.value!.path
              .split('/')
              .last, // Get filename from path
        ),
      });

      // Perform the POST request using the postFormData method from ApiProvider
      final response = await _apiProvider.postFormData(
        '/general-module/bug-reports', // Make sure this is the correct endpoint
        form,
      );
      debugPrint(
        'API Response Status Code: ${response.statusCode}',
      ); // Debug debugPrint
      debugPrint('API Response Body: ${response.body}'); // Debug debugPrint

      // Handle API response
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Check for 201 Created as well
        _showSnackbar(
          'Sukses',
          'Laporan bug berhasil dikirim!',
          isSuccess: true,
        );
        // Delay navigation slightly to allow Snackbar to fully show
        Future.delayed(const Duration(milliseconds: 500), () {
          _clearForm(); // Clear form on success
          Get.offAllNamed(ProfileRoutes.PROFILE); // Navigate back
        });
      } else {
        String errorMessage = 'Gagal mengirim laporan bug.';
        Map<String, dynamic>? errorBody;
        try {
          if (response.body is Map) {
            errorBody = response.body as Map<String, dynamic>;
          } else if (response.bodyString != null &&
              response.bodyString!.isNotEmpty) {
            errorBody =
                json.decode(response.bodyString!) as Map<String, dynamic>;
          }
        } catch (e) {
          debugPrint('Error decoding error response body: $e');
        }

        errorMessage =
            errorBody?['message'] ??
            errorBody?['error'] ?? // Check for common error keys
            'Gagal mengirim laporan bug. Status: ${response.statusCode ?? '-'}';
        _showSnackbar('Gagal', errorMessage, isError: true);
      }
    } catch (e) {
      debugPrint('Error submitting bug report: $e');
      _showSnackbar(
        'Error',
        'Terjadi kesalahan: ${e.toString()}',
        isError: true,
      );
    } finally {
      isLoading(false); // Deactivate loading indicator
    }
  }

  /// Clears all form fields and resets the image.
  void _clearForm() {
    titleController.clear();
    messageController.clear();
    selectedPlatform.value = 'android'; // Reset to default
    status.value = true; // Reset to default
    pickedImage.value = null; // Clear picked image
    bugReportFormKey.currentState?.reset(); // Reset form validation state
  }

  /// Shows a customized GetX Snackbar.
  void _showSnackbar(
    String title,
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    // Check if a Snackbar is already open to prevent multiple concurrent ones
    // and potential overlap issues.
    if (Get.isSnackbarOpen) {
      Get.back(closeOverlays: true); // Close existing snackbars/dialogs
    }

    Color backgroundColor;
    Color textColor;

    if (isError) {
      backgroundColor = Get.theme.colorScheme.error;
      textColor = Get.theme.colorScheme.onError;
    } else if (isSuccess) {
      backgroundColor = Get.theme.colorScheme.primary;
      textColor = Get.theme.colorScheme.onPrimary;
    } else {
      backgroundColor = Get.theme.colorScheme.surface;
      textColor = Get.theme.colorScheme.onSurfaceVariant;
    }

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: backgroundColor,
      colorText: textColor,
      margin: const EdgeInsets.all(10),
      borderRadius: 8,
      duration: const Duration(
        seconds: 3,
      ), // Ensure it stays long enough to be seen
      snackStyle: SnackStyle.FLOATING, // Often looks better
    );
  }
}
