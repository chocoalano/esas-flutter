import 'package:esas/app/data/Profile/user.m.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ProfileWorkedController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  Rx<User> userInfo = User().obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  @override
  void onInit() {
    super.onInit();
    setupProfile();
  }

  Future<void> setupProfile() async {
    isLoading.value = true;
    try {
      final response = await _apiProvider.get('/general-module/auth');
      final resData = response.body as Map<String, dynamic>;
      userInfo.value = User.fromJson(resData['user']);
      debugPrint("Info profile Loaded: total_absensi = $resData");
    } catch (e) {
      debugPrint("Error Info profile: $e");
      errorMessage('Data pengguna tidak ditemukan.');
    } finally {
      isLoading.value = false;
    }
  }

  // --- Getters for formatted employment data ---

  String get companyName => userInfo.value.company?.name ?? '-';

  String get departmentName =>
      userInfo.value.employee?.departement?.name ?? '-';

  String get jobPosition => userInfo.value.employee?.jobPosition?.name ?? '-';

  String get jobLevel => userInfo.value.employee?.jobLevel?.name ?? '-';

  String get joinDate {
    if (userInfo.value.employee?.joinDate != null) {
      return DateFormat(
        'dd MMMM yyyy',
      ).format(userInfo.value.employee!.joinDate!);
    }
    return '-';
  }

  String get signDate {
    if (userInfo.value.employee?.signDate != null) {
      return DateFormat(
        'dd MMMM yyyy',
      ).format(userInfo.value.employee!.signDate!);
    }
    return '-';
  }

  String get resignDate {
    if (userInfo.value.employee?.resignDate != null) {
      // Assuming resignDate can be a DateTime or String
      if (userInfo.value.employee!.resignDate is DateTime) {
        return DateFormat(
          'dd MMMM yyyy',
        ).format(userInfo.value.employee!.resignDate as DateTime);
      } else if (userInfo.value.employee!.resignDate is String &&
          userInfo.value.employee!.resignDate!.isNotEmpty) {
        try {
          return DateFormat(
            'dd MMMM yyyy',
          ).format(DateTime.parse(userInfo.value.employee!.resignDate!));
        } catch (e) {
          debugPrint('Error parsing resignDate string: $e');
          return userInfo.value.employee!.resignDate?.toString() ??
              '-'; // Fallback to raw string if parsing fails
        }
      }
    }
    return '-';
  }

  String get bankName => userInfo.value.employee?.bankName ?? '-';

  String get bankNumber => userInfo.value.employee?.bankNumber ?? '-';

  String get bankHolder => userInfo.value.employee?.bankHolder ?? '-';

  String get basicSalary {
    if (userInfo.value.salaries?.basicSalary != null) {
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp',
        decimalDigits: 0,
      );
      return formatter.format(userInfo.value.salaries!.basicSalary);
    }
    return '-';
  }

  String get paymentType => userInfo.value.salaries?.paymentType ?? '-';

  String get approvalLine => userInfo.value.employee?.approvalLine?.name ?? '-';
  String get approvalManager =>
      userInfo.value.employee?.approvalManager?.name ?? '-';

  String get saldoCuti {
    if (userInfo.value.employee?.saldoCuti != null) {
      return userInfo.value.employee!.saldoCuti.toString();
    }
    return '-';
  }
}
