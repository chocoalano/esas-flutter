import 'dart:convert';

import 'package:esas/app/routes/app_pages.dart';
import 'package:esas/app/services/api_external_provider.dart';
import 'package:esas/app/widgets/controllers/storage_keys.dart';
import 'package:flutter/material.dart'; // Import for debugPrint
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; // Required for PlatformException
import 'package:esas/app/widgets/views/snackbar.dart'; // Ensure this path is correct for your custom snackbars

class AttendanceController extends GetxController {
  final ApiExternalProvider _apiExtProvider = Get.find<ApiExternalProvider>();
  // Mobile Scanner Controller
  late final MobileScannerController mobileScannerController;
  final GetStorage _storage = GetStorage(); // Instance of GetStorage

  // Observable states for UI updates
  final scannedCode = ''.obs;
  final isProcessing = false.obs; // For submission loading state
  final isTorchOn = false.obs; // For camera flash state
  final isLocationValid =
      false.obs; // True if within range, not mocked, and services enabled
  final isLoadingLocation =
      false.obs; // True while fetching/validating location

  // --- Geolocation Configuration (Observable for dynamic updates) ---
  final RxDouble _targetLatitude = 0.0.obs;
  final RxDouble _targetLongitude = 0.0.obs;
  final RxDouble _allowedDistanceMeters = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize MobileScannerController
    mobileScannerController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );

    // Call _initializeLocationData and then validate
    _initializeLocationDataAndValidate();
  }

  /// Initializes location data from GetStorage and then validates the device's location.
  Future<void> _initializeLocationDataAndValidate() async {
    final user = _storage.read(StorageKeys.userJson);
    debugPrint("======> ini data user: $user");
    // _targetLatitude.value = -6.2183282; //ini lat rumah
    _targetLatitude.value =
        (user?['company']?['latitude'] as num?)?.toDouble() ??
        -6.17566156928234;
    // _targetLongitude.value = 106.5411286; //ini lng rumah
    _targetLongitude.value =
        (user?['company']?['longitude'] as num?)?.toDouble() ??
        106.599255891093;
    _allowedDistanceMeters.value = 30.0;
    // (user?['company']?['radius'] as num?)?.toDouble() ?? 30.0;
    debugPrint("Parsed Latitude: ${_targetLatitude.value}");
    debugPrint("Parsed Longitude: ${_targetLongitude.value}");
    debugPrint("Parsed Radius: ${_allowedDistanceMeters.value}");
    await _validateDeviceLocation();
  }

  /// Validates the device's current geolocation for attendance purposes.
  ///
  /// This method performs the following checks:
  /// 1. Verifies if location services (GPS) are enabled on the device.
  /// 2. Requests/checks for necessary location permissions.
  /// 3. Retrieves the device's current position with high accuracy.
  /// 4. **Crucially, checks if the obtained location is a mock location (Fake GPS).**
  /// 5. Calculates the distance to the predefined target attendance location.
  /// 6. Updates `isLocationValid` state based on distance and mock status.
  Future<void> _validateDeviceLocation() async {
    // Set loading state to true
    isLoadingLocation.value = true;
    isLocationValid.value = false; // Reset validity until proven valid

    try {
      // 1. Check if location services are enabled on the device (e.g., GPS is on)
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        showWarningSnackbar(
          'Layanan lokasi dinonaktifkan. Harap aktifkan GPS Anda di pengaturan perangkat.',
          title: 'GPS Tidak Aktif',
        );
        return; // Exit if services are off
      }

      // 2. Request/Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showErrorSnackbar(
            'Izin lokasi ditolak. Harap berikan izin lokasi untuk menggunakan fitur ini.',
            title: 'Izin Ditolak',
          );
          return; // Exit if permission denied
        }
      }
      if (permission == LocationPermission.deniedForever) {
        showErrorSnackbar(
          'Izin lokasi ditolak secara permanen. Buka pengaturan aplikasi untuk mengizinkan lokasi.',
          title: 'Izin Ditolak Permanen',
        );
        await openAppSettings(); // Direct user to app settings
        return; // Exit if permission permanently denied
      }

      // 3. Get current device position with high accuracy and a timeout
      // Use forceAndroidLocationManager: true if facing issues on some Android devices
      // but generally not needed unless specific problems arise.
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(
          seconds: 15,
        ), // Increased timeout for better chance of getting a fix
      );

      // 4. --- Crucial: Check for Mock Location ---
      if (currentPosition.isMocked) {
        showErrorSnackbar(
          'Terdeteksi penggunaan lokasi palsu (Fake GPS). Absensi tidak diizinkan.',
          title: 'Lokasi Palsu Terdeteksi',
        );
        isLocationValid.value = false;
        return;
      }

      // 5. Calculate distance to the target attendance location
      double distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        _targetLatitude.value, // Use .value for RxDouble
        _targetLongitude.value, // Use .value for RxDouble
      );
      // print("===============>> distance: $distanceInMeters");
      // print("================> posisi saat ini :${currentPosition.latitude}");
      // print("================> posisi saat ini :${currentPosition.longitude}");

      // 6. Compare distance with the allowed range
      if (distanceInMeters <= _allowedDistanceMeters.value) {
        isLocationValid.value = true;
        showSuccessSnackbar(
          'Anda berada dalam jangkauan absensi (${distanceInMeters.toStringAsFixed(2)} meter).',
          title: 'Lokasi Valid',
        );
      } else {
        showErrorSnackbar(
          'Anda berada di luar jangkauan absensi (${distanceInMeters.toStringAsFixed(2)} meter). Jarak yang diizinkan adalah ${_allowedDistanceMeters.toStringAsFixed(0)} meter.',
          title: 'Lokasi Tidak Valid',
        );
        isLocationValid.value = false; // Location is invalid if too far
      }
    } on PlatformException catch (e) {
      String errorMessage =
          'Terjadi kesalahan platform terkait lokasi: ${e.message}';
      debugPrint(
        'PlatformException during location validation: ${e.code} - ${e.message}',
      );
      showErrorSnackbar(errorMessage, title: 'Kesalahan Lokasi');
    } on LocationServiceDisabledException {
      showWarningSnackbar(
        'Layanan lokasi dinonaktifkan. Harap aktifkan GPS Anda.',
        title: 'GPS Tidak Aktif',
      );
    } catch (e) {
      debugPrint('Unexpected error during location validation: $e');
      showErrorSnackbar(
        'Gagal mendapatkan lokasi perangkat: ${e.toString()}. Coba lagi.',
        title: 'Kesalahan Umum',
      );
    } finally {
      isLoadingLocation.value =
          false; // Always set loading to false in finally block
    }
  }

  /// Handles the detection of a QR code.
  /// Only processes the QR code if location is valid and not already processing.
  void onQRScanned(BarcodeCapture capture) async {
    // Prevent multiple scans or processing if location is not valid
    if (isProcessing.value || !isLocationValid.value) {
      if (!isLocationValid.value) {
        showErrorSnackbar(
          'Lokasi Anda tidak valid untuk absensi. Pastikan GPS aktif dan Anda berada dalam jangkauan yang diizinkan.',
          title: 'Gagal Absensi',
        );
      }
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        scannedCode.value = code; // Store the scanned code
        await mobileScannerController
            .stop(); // Stop scanning to prevent multiple detections

        await _submitAttendance(code); // Attempt to submit attendance

        scannedCode.value = ''; // Clear scanned code after submission attempt
        // Restart scanner if still on the attendance scanner page
        if (Get.currentRoute == '/attendance_scanner') {
          await mobileScannerController.start();
        }
      }
    }
  }

  /// Simulates submitting attendance data (QR code) to a backend.
  /// In a real application, you would send the actual current location data here.
  Future<void> _submitAttendance(String qrCode) async {
    isProcessing.value = true;
    try {
      // Get the current valid position to send with attendance (optional but recommended)
      Position? currentValidPosition;
      try {
        currentValidPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(
            seconds: 5,
          ), // Shorter timeout as location should already be valid
        );
      } catch (e) {
        Get.offAllNamed(Routes.ATTENDANCE_LIST);
        debugPrint("Could not get current position for submission: $e");
        // Optionally, show a warning if location can't be re-acquired right before submission
        showWarningSnackbar(
          'Gagal mendapatkan lokasi akurat untuk pengiriman. Absensi mungkin tidak tercatat lengkap.',
          title: 'Perhatian Lokasi',
        );
      }

      // --- Replace with your actual API call to submit attendance ---
      debugPrint(
        "Submitting QR: $qrCode with location: ${currentValidPosition?.latitude}, ${currentValidPosition?.longitude}",
      );
      Map<String, dynamic> qrCodeData;
      try {
        qrCodeData = json.decode(qrCode)['data'];
      } catch (e) {
        // If qrCode is not a valid JSON string, handle the error
        debugPrint("Error decoding QR code as JSON: $e");
        showErrorSnackbar(
          'Format QR Code tidak valid. Harap gunakan QR Code yang benar.',
          title: 'QR Code Invalid',
        );
        isProcessing.value = false; // Stop processing
        return; // Exit the method
      }
      final user = _storage.read(StorageKeys.userJson);
      final int? currentStorageDeptId =
          (user?['employee']?['departement_id'] as num?)?.toInt();
      final int? currentUserId = (user?['employee']?['user_id'] as num?)
          ?.toInt();
      final int? currentQrDeptId = int.tryParse(qrCodeData['departement_id']);
      final String? qrType = qrCodeData['type'];
      final int? qrId = int.tryParse(qrCodeData['id']);

      debugPrint(
        "User Dept ID from Storage: $currentStorageDeptId from qrcode: $currentQrDeptId",
      );
      debugPrint("QR Dept ID: $currentQrDeptId");
      if (currentStorageDeptId == currentQrDeptId) {
        final payload = {
          "type": qrType,
          "token_id": qrId,
          "user_id": currentUserId,
        };
        debugPrint("========> ini data dikirimnya boss : $payload");

        const String baseApiUrl = 'http://128.199.111.239:3000';
        final response = await _apiExtProvider.postExternal(
          "$baseApiUrl/attmachine/qr-presence",
          payload,
        );
        if (response.statusCode == 200) {
          showSuccessSnackbar(
            'Absensi ${qrType == 'in' ? 'Masuk' : 'Pulang'} Berhasil',
          );
        } else {
          final Map<String, dynamic> data = response.body;
          // print("ini response error nya $data");
          showErrorSnackbar(data['message'], title: 'Kesalahan Pengiriman');
        }
      } else {
        showErrorSnackbar(
          'Pengiriman gagal: Kode QR ini bukan untuk departemen anda!',
          title: 'Kesalahan Pengiriman',
        );
      }
    } catch (e) {
      showErrorSnackbar(
        'Pengiriman gagal: ${e.toString()}',
        title: 'Kesalahan Pengiriman',
      );
    } finally {
      isProcessing.value = false;
      Get.offAllNamed(Routes.ATTENDANCE_LIST);
    }
  }

  /// Toggles the camera's flash (torch) on or off.
  Future<void> toggleFlash() async {
    await mobileScannerController.toggleTorch();
    isTorchOn.value =
        !isTorchOn.value; // Update local state based on actual flash state
  }

  /// Switches between front and back cameras.
  Future<void> flipCamera() async {
    await mobileScannerController.switchCamera();
  }

  @override
  void onClose() {
    // Dispose of the scanner controller to prevent memory leaks
    mobileScannerController.dispose();
    super.onClose();
  }

  /// Public method to allow the UI to re-trigger location validation.
  /// This is called by the "Coba Lagi Lokasi" button in the view.
  Future<void> revalidateLocation() async {
    await _initializeLocationDataAndValidate(); // Re-initialize and then validate
  }
}
