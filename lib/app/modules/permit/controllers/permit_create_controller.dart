// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:esas/app/data/Permit/leave_type.m.dart';
import 'package:esas/app/data/Permit/permit_type.m.dart';
import 'package:esas/app/data/Permit/timework.m.dart';
import 'package:esas/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:esas/app/data/Permit/schedule.m.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:esas/app/widgets/controllers/storage_keys.dart';
import 'package:esas/app/widgets/views/snackbar.dart';
import 'package:intl/intl.dart';

class PermitCreateController extends GetxController {
  final GetStorage _storage = GetStorage();
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final formKey = GlobalKey<FormState>();

  final permitNumberC = TextEditingController();
  final timeinAdjustC = TextEditingController();
  final timeoutAdjustC = TextEditingController();
  final startDateC = TextEditingController();
  final endDateC = TextEditingController();
  final startTimeC = TextEditingController();
  final endTimeC = TextEditingController();
  final notesC = TextEditingController();

  final Rx<LeaveType> createType = LeaveType(
    id: 0,
    type: '',
    isPayed: false,
    approveLine: false,
    approveManager: false,
    approveHr: false,
    withFile: false,
    showMobile: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ).obs;

  final scheduleList = <Schedule>[].obs;
  final permitTypeList = <PermitType>[].obs;
  final shiftList = <Timework>[].obs;

  final selectedScheduleId = RxnInt();
  final selectedPermitTypeId = RxnInt();
  final selectedCurrentShiftId = RxnInt();
  final selectedAdjustShiftId = RxnInt();

  final selectedFile = Rxn<PlatformFile>();

  @override
  void onInit() {
    super.onInit();
    final dynamic args = Get.arguments;
    createType.value = args;
    selectedPermitTypeId.value = createType.value.id;
    _loadInitialData();
  }

  @override
  void onClose() {
    permitNumberC.dispose();
    timeinAdjustC.dispose();
    timeoutAdjustC.dispose();
    startDateC.dispose();
    endDateC.dispose();
    startTimeC.dispose();
    endTimeC.dispose();
    notesC.dispose();
    super.onClose();
  }

  void onScheduleChanged(int? newId) {
    selectedScheduleId.value = newId;
    final schedule = scheduleList.firstWhereOrNull((s) => s.id == newId);
    final workDate = schedule?.workDay is DateTime
        ? schedule?.workDay
        : DateTime.tryParse(schedule?.workDay.toString() ?? '');
    final formatted = workDate != null ? dateFormatter.format(workDate) : '';
    startDateC.text = formatted;
    endDateC.text = formatted;
  }

  Future<void> _loadInitialData() async {
    isLoading.value = true;
    try {
      final user = _storage.read(StorageKeys.userJson) as Map<String, dynamic>?;
      if (user == null) {
        showErrorSnackbar('Data pengguna tidak ditemukan.');
        return;
      }

      final params = {
        'companyId': (user['company_id'] ?? '').toString(),
        'deptId': (user['employee']?['departement_id'] ?? '').toString(),
        'userId': (user['id'] ?? '').toString(),
        'typeId': selectedPermitTypeId.value.toString(),
      };

      final response = await _apiProvider.get(
        '/hris-module/permits/create',
        params: params,
      );

      if (response.statusCode == 200) {
        final data = response.body['form'] as Map<String, dynamic>?;
        if (data == null) return;
        print(data['schedules']);
        scheduleList.assignAll(
          (data['schedules'] as List?)
                  ?.map((e) => Schedule.fromJson(e))
                  .toList() ??
              [],
        );
        if (scheduleList.isNotEmpty) {
          selectedScheduleId.value = scheduleList.first.id;
        }

        shiftList.assignAll(
          (data['timeworks'] as List?)
                  ?.map((e) => Timework.fromJson(e))
                  .toList() ??
              [],
        );
        if (shiftList.isNotEmpty) {
          selectedCurrentShiftId.value = shiftList.first.id;
          selectedAdjustShiftId.value = shiftList.first.id;
        }

        permitNumberC.text = data['permit_numbers'] ?? '';
      } else {
        _showApiError(response.statusCode!, response.body);
      }
    } catch (e) {
      showErrorSnackbar('Gagal memuat data awal: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createPermit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      showWarningSnackbar('Periksa kembali formulir.');
      return;
    }

    final user = _storage.read(StorageKeys.userJson) as Map<String, dynamic>?;
    if (user == null) {
      showErrorSnackbar('Data pengguna tidak ditemukan.');
      return;
    }

    isSubmitting.value = true;
    try {
      final fields = {
        'company_id': user['company_id'],
        'departement_id': user['employee']['departement_id'],
        'user_id': user['id'],
        'permit_numbers': permitNumberC.text,
        'user_timework_schedule_id': selectedScheduleId.value?.toString() ?? '',
        'permit_type_id': selectedPermitTypeId.value?.toString() ?? '',
        'time_in_adjust': timeinAdjustC.text,
        'time_out_adjust': timeoutAdjustC.text,
        'current_shift_id': selectedCurrentShiftId.value?.toString() ?? '',
        'adjust_shift_id': selectedAdjustShiftId.value?.toString() ?? '',
        'start_date': startDateC.text,
        'end_date': endDateC.text,
        'start_time': startTimeC.text.replaceAll('.', ':'),
        'end_time': endTimeC.text.replaceAll('.', ':'),
        'notes': notesC.text,
      };
      debugPrint("ini data post $fields");
      final formData = FormData({});
      fields.forEach((k, v) {
        final stringValue = v?.toString().trim();
        if (stringValue != null && stringValue.isNotEmpty) {
          formData.fields.add(MapEntry(k, stringValue));
        }
      });

      if (selectedFile.value?.path != null) {
        final file = selectedFile.value!;
        formData.files.add(
          MapEntry(
            'file',
            MultipartFile(File(file.path!), filename: file.name),
          ),
        );
      }

      final res = await _apiProvider.postFormData(
        '/hris-module/permits',
        formData,
      );
      if (res.statusCode == 200) {
        showSuccessSnackbar('Permohonan izin berhasil dibuat!');
        Get.offAllNamed(Routes.PERMIT_LIST, arguments: createType.value);
      } else {
        _showApiError(res.statusCode!, res.body);
      }
    } catch (e) {
      debugPrint("=======error ${e.toString()}");
      showErrorSnackbar('Gagal membuat permohonan: $e');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xlsx'],
    );
    selectedFile.value = result?.files.single;
  }

  Future<void> pickDate(BuildContext context, TextEditingController c) async {
    final initialDate = DateTime.tryParse(c.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) c.text = dateFormatter.format(picked);
  }

  Future<void> pickTime(BuildContext context, TextEditingController c) async {
    final parts = c.text.split(':');
    final initialTime = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked != null) {
      c.text = picked.format(context);
    }
  }

  void _showApiError(int code, dynamic body) {
    String msg = 'Terjadi kesalahan saat mengirim data.';
    if (body is Map && body.containsKey('message')) {
      msg = body['message'];
    } else if (body is Map && body['errors'] is Map) {
      final errors = body['errors'] as Map<String, dynamic>;
      msg = errors.values.expand((e) => e as List).join('\n');
    } else if (body is String) {
      msg = body;
    }
    showErrorSnackbar('Error $code: $msg');
  }
}
