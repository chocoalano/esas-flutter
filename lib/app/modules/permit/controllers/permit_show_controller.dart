import 'dart:async';
import 'dart:io';

import 'package:esas/app/data/Permit/leave_type.m.dart';
import 'package:esas/utils/helper.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/views/snackbar.dart'; // Ensure this provides showErrorSnackbar, showSuccessSnackbar, showInfoSnackbar
import 'package:esas/app/data/Permit/leave_list.m.dart';
import 'package:esas/app/widgets/controllers/storage_keys.dart'; // Assuming StorageKeys.userId exists

/// Controller untuk menampilkan detail perizinan
/// dan meng-handle logika approval berdasarkan user saat ini.
class PermitShowController extends GetxController {
  // Dependencies
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final GetStorage _storage = GetStorage();

  // ID user saat ini
  // Menggunakan late final untuk inisialisasi di onInit, dengan fallback 0
  late final int currentUserId;

  // State loading dan data permit
  final RxBool isLoading = true.obs;
  final Rx<Permit?> permit = Rx<Permit?>(null);

  // State approval
  // canApprove: Menentukan apakah tombol approve/reject harus ditampilkan
  // myApproval: Menyimpan objek Approval spesifik untuk user yang sedang login
  final RxBool canApprove = false.obs;
  final Rx<Approval?> myApproval = Rx<Approval?>(null);
  final permitId = 0.obs; // RxInt
  final permitType = Rx<LeaveType?>(null); // Rx object

  @override
  void onInit() {
    super.onInit();
    // Memuat ID user saat ini dari local storage.
    // Jika tidak ada, default ke 0 (atau nilai yang menunjukkan user tidak terautentikasi/invalid).
    currentUserId = _storage.read<int>(StorageKeys.userId) ?? 0;
    if (kDebugMode) debugPrint('Current User ID from Storage: $currentUserId');

    _extractPermitId(); // Mengambil ID perizinan dari argumen
    loadPermitDetails(); // Memuat detail perizinan

    // Menambahkan listener untuk memanggil _evaluateApproval() setiap kali
    // data permit berubah (setelah fetch atau refresh).
    ever(permit, (_) => _evaluateApproval());
  }

  /// Ambil permitId dari Get.arguments
  void _extractPermitId() {
    final args = Get.arguments;

    if (args is Map<String, dynamic>) {
      final permit = args['permit'] as Permit?;
      final id = args['id'] as int?;

      if (permit != null) {
        // kalau permitType = Rx<LeaveType?>
        permitType.value = permit.permitType;
      }

      if (id != null) {
        permitId.value = id;
      }
    }
  }

  /// Fetch detail perizinan dari API
  Future<void> loadPermitDetails() async {
    // Jangan lakukan panggilan API jika permitId tidak valid atau user tidak terautentikasi
    if (permitId == 0 || currentUserId == 0) {
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    final url = '/hris-module/permits/$permitId';
    try {
      final response = await _apiProvider.get(url);
      if (response.statusCode == 200) {
        // Asumsi body response adalah Map langsung, sesuaikan jika ada key 'data'
        final data = response.body as Map<String, dynamic>;
        permit.value = Permit.fromJson(data);
        // _evaluateApproval() akan dipanggil otomatis oleh listener 'ever'
      } else {
        showApiError(response.statusCode, response.body);
        permit.value = null; // Clear data on error
      }
    } on SocketException {
      showErrorSnackbar(
        'Tidak ada koneksi internet. Mohon periksa koneksi Anda.',
      );
      permit.value = null;
    } on TimeoutException {
      showErrorSnackbar('Koneksi terlalu lama. Mohon coba lagi.');
      permit.value = null;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading permit: $e');
      showErrorSnackbar('Gagal mengambil detail perizinan.');
      permit.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Tentukan apakah user dapat approve dan temukan objek approvalnya
  void _evaluateApproval() {
    final p = permit.value;
    if (p == null) {
      myApproval.value = null;
      canApprove.value = false;
      return;
    }

    // Menggunakan firstWhereOrNull untuk pencarian yang lebih aman
    final foundApproval = p.approvals.firstWhereOrNull(
      (a) => a.userId == currentUserId,
    );

    myApproval.value = foundApproval; // Simpan objek approval user ini
    // User bisa approve jika approval ditemukan dan statusnya 'w' (waiting/pending)
    canApprove.value =
        foundApproval != null &&
        foundApproval.userApprove!.toLowerCase() == 'w';

    if (kDebugMode) debugPrint('canApprove=${canApprove.value}');
  }

  /// Kirim persetujuan atau penolakan ke API
  /// [approve]: true untuk menyetujui, false untuk menolak
  /// [notes]: Catatan tambahan (opsional)
  Future<void> submitApproval({required bool approve, String? notes}) async {
    final approvalToSubmit = myApproval.value;
    if (approvalToSubmit == null) {
      showErrorSnackbar(
        'Tidak ada peran persetujuan untuk Anda pada perizinan ini.',
      );
      return;
    }

    isLoading.value = true;
    final actionStatus = approve
        ? 'y'
        : 'n'; // Status yang akan dikirim ke backend
    final String url =
        '/hris-module/permits/$permitId/approval'; // Endpoint untuk submit approval
    final Map<String, dynamic> payload = {
      'approval_id': approvalToSubmit.id, // ID approval yang akan di-update
      'user_approve': actionStatus,
    };

    if (notes != null && notes.isNotEmpty) {
      payload['notes'] = notes;
    }

    try {
      final response = await _apiProvider.put(url, payload);
      if (kDebugMode) {
        debugPrint("response nya gini bosskuh ===> : ${response.body}");
      }
      if (response.statusCode == 200) {
        // Asumsi API mengembalikan pesan sukses atau data yang diupdate
        final successMessage = approve
            ? 'Persetujuan berhasil dikirim.'
            : 'Penolakan berhasil dikirim.';
        showSuccessSnackbar(successMessage);
        await loadPermitDetails(); // Muat ulang detail untuk update UI
      } else {
        showApiError(response.statusCode, response.body);
      }
    } on SocketException {
      showErrorSnackbar('Tidak ada koneksi internet.');
    } on TimeoutException {
      showErrorSnackbar('Koneksi terlalu lama.');
    } catch (e) {
      if (kDebugMode) debugPrint('Error submitting approval: $e');
      showErrorSnackbar('Gagal mengirim persetujuan.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Tampilkan pesan error dari API
}
