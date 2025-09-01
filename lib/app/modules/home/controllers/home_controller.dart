import 'dart:async';
import 'dart:io';

import 'package:esas/app/data/activity/log.m.dart';
import 'package:esas/app/data/announcement/list.m.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/controllers/storage_keys.dart';
import 'package:esas/app/widgets/views/snackbar.dart';

import 'attribute.m.dart';

class HomeController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final GetStorage _storage = GetStorage();

  // Observables
  final userName = 'Anonymous'.obs;
  final userAvatarUrl = ''.obs;
  final currentDate = ''.obs;
  final isLoading = false.obs;

  final RxList<SummaryCard> summaryCards = <SummaryCard>[].obs;
  final RxList<ActivityLog> activityLog = <ActivityLog>[].obs;
  final RxList<Announcement> announcements = <Announcement>[].obs;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  void _initialize() {
    _loadUserInfo();
    _setCurrentDate();
    _loadStaticData();
    fetchCurrentAttendance();
    fetchCurrentSchedule();
    fetchAnnouncement();
    fetchActivity();
  }

  void _loadUserInfo() {
    final Map<String, dynamic> user = _storage.read(StorageKeys.userJson) ?? {};
    userName.value = user['name'] ?? 'Anonymous';
    userAvatarUrl.value = user['avatar'] ?? '';
  }

  void _setCurrentDate() {
    currentDate.value = DateFormat(
      'EEEE, d MMMM yyyy',
      'id',
    ).format(DateTime.now());
  }

  void _loadStaticData() {
    summaryCards.assignAll([
      SummaryCard(
        title: 'Absen Masuk',
        time: '--:--',
        status: '—',
        icon: Icons.login,
      ),
      SummaryCard(
        title: 'Absen Pulang',
        time: '--:--',
        status: '—',
        icon: Icons.logout,
      ),
      SummaryCard(
        title: 'Jadwal Masuk',
        time: '--:--',
        status: '—',
        icon: Icons.calendar_today_outlined,
      ),
      SummaryCard(
        title: 'Jadwal Pulang',
        time: '--:--',
        status: '—',
        icon: Icons.calendar_today_outlined,
      ),
    ]);
  }

  Future<void> fetchCurrentAttendance() async {
    await _performApiCall<int, Map<String, dynamic>>(
      readKey: StorageKeys.userId,
      endpoint: (id) => '/general-module/auth/current-attendance/$id',
      onSuccess: _updateAttendanceCards,
    );
  }

  Future<void> fetchCurrentSchedule() async {
    await _performApiCall<void, Map<String, dynamic>>(
      endpoint: (_) => '/general-module/auth/schedule',
      onSuccess: _updateScheduleCards,
    );
  }

  Future<void> fetchAnnouncement() async {
    await _performApiCall<void, List<dynamic>>(
      endpoint: (_) => '/general-module/announcements/active',
      onSuccess: _updateAnnouncementSlider,
    );
  }

  Future<void> fetchActivity() async {
    await _performApiCall<void, List<dynamic>>(
      endpoint: (_) => '/general-module/auth/activity',
      onSuccess: _updateActivityList,
    );
  }

  Future<void> _performApiCall<R, T>({
    String? readKey,
    required String Function(R? id) endpoint,
    required void Function(T data) onSuccess,
  }) async {
    isLoading.value = true;
    try {
      R? id;
      if (readKey != null) {
        id = _storage.read<R>(readKey);
        if (id == null) {
          throw PlatformException(
            code: 'NO_ID',
            message: 'ID pengguna tidak tersedia',
          );
        }
      }

      final response = await _apiProvider.get(endpoint(id));
      if (response.statusCode == 200) {
        try {
          onSuccess(response.body as T);
        } catch (e) {
          throw FormatException('Response format tidak sesuai');
        }
      } else {
        _handleApiError(response.statusCode, response.body);
      }
    } on SocketException {
      showErrorSnackbar('Tidak ada koneksi internet.');
    } on TimeoutException {
      showErrorSnackbar('Koneksi terlalu lama.');
    } on FormatException catch (e) {
      showErrorSnackbar(e.message);
    } on PlatformException catch (e) {
      showErrorSnackbar(e.message ?? 'Gagal mendapatkan info perangkat.');
    } catch (e) {
      if (kDebugMode) debugPrint('Unexpected error: $e');
      showErrorSnackbar('Terjadi kesalahan tidak terduga.');
    } finally {
      isLoading.value = false;
    }
  }

  void _updateAttendanceCards(Map<String, dynamic> data) {
    if (kDebugMode) {
      print("================ kesini boss ${data.toString()}");
    }
    final inTime = data['time_in'] as String? ?? '--:--';
    final outTime = data['time_out'] as String? ?? '--:--';
    final inStatus = data['status_in'] as String? ?? '—';
    final outStatus = data['status_out'] as String? ?? '—';

    summaryCards[0] = summaryCards[0].copyWith(time: inTime, status: inStatus);
    summaryCards[1] = summaryCards[1].copyWith(
      time: outTime,
      status: outStatus,
    );
  }

  void _updateScheduleCards(Map<String, dynamic> data) {
    final timework = data['timework'] as Map<String, dynamic>?;
    if (timework == null) return;

    final inTime = timework['in'] as String? ?? '--:--';
    final outTime = timework['out'] as String? ?? '--:--';
    final status = timework['name'] as String? ?? '—';

    summaryCards[2] = summaryCards[2].copyWith(time: inTime, status: status);
    summaryCards[3] = summaryCards[3].copyWith(time: outTime, status: status);
  }

  void _updateAnnouncementSlider(List<dynamic> data) {
    // Mengonversi list JSON menjadi model Announcement
    final items = data
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();
    announcements.assignAll(items);
  }

  void _updateActivityList(List<dynamic> data) {
    // Mengonversi list JSON menjadi model Announcement
    final items = data
        .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
        .toList();
    activityLog.assignAll(items);
  }

  void _handleApiError(int? statusCode, dynamic body) {
    if (kDebugMode) debugPrint('API Error [$statusCode]: $body');

    final message = switch (statusCode) {
      400 => 'Permintaan tidak valid.',
      401 => 'Akses ditolak. Silakan login ulang.',
      403 => 'Anda tidak memiliki izin.',
      404 => 'Data tidak ditemukan.',
      422 => _extractValidationError(body),
      500 => 'Kesalahan server. Coba lagi nanti.',
      _ => 'Error tidak diketahui (kode: \$statusCode).',
    };

    showErrorSnackbar(message);
  }

  String _extractValidationError(dynamic body) {
    if (body is Map && body['errors'] is Map) {
      final errors = body['errors'] as Map;
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        return first.first.toString();
      }
    }
    if (body is Map && body['message'] is String) {
      return body['message'] as String;
    }
    return 'Data tidak valid.';
  }
}
