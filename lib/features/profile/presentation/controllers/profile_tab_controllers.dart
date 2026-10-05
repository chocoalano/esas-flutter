import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/data/repositories/session_repository.dart';
import '../../data/models/payslip.dart';
import '../../data/repositories/payroll_repository.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/models/foeducation.dart';
import '../../data/models/ineducation.dart';
import '../../data/models/user.dart';
import '../../data/models/workexp.dart';
import 'profile_section_controller.dart';

/// Tanggal ditulis dalam bahasa Indonesia, dan itu harus dinyatakan.
///
/// `DateFormat('dd MMMM yyyy')` tanpa argumen locale memakai locale baku proses
/// — yang di aplikasi ini berarti `en_US` — sehingga tanggal lahir seorang
/// karyawan pabrik tercetak "15 February 1990" di satu-satunya layar berbahasa
/// Indonesia yang ia buka untuk membacakannya kembali ke HR.
///
/// Nilai-nilai di sini adalah TANGGAL, bukan stempel waktu: ulang tahun dan
/// tanggal bergabung menamai hari kalender yang sama di zona mana pun. Karena
/// itu keduanya sengaja tidak melewati konversi jam kerja workspace — memberi
/// zona kepada sebuah tanggal justru cara ulang tahun bergeser satu hari.
final _dayMonthYear = DateFormat('dd MMMM yyyy', 'id');
final _year = DateFormat('yyyy', 'id');
final _dayShortMonthYear = DateFormat('dd MMM yyyy', 'id');
final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

String _date(DateTime? value) =>
    value == null ? '-' : _dayMonthYear.format(value);

class ProfilePersonalController extends ProfileSectionController {
  ProfilePersonalController({required super.repository});

  String get formattedJoinedDate => _date(userInfo.value.details?.datebirth);

  String get fullAddress {
    final address = userInfo.value.address;

    if (address == null) {
      return '-';
    }

    final parts = [
      address.citizenAddress,
      address.city,
      address.province,
    ].whereType<String>().where((p) => p.isNotEmpty);

    return parts.isEmpty ? '-' : parts.join(', ');
  }
}

class ProfileWorkedController extends ProfileSectionController {
  ProfileWorkedController({required super.repository});

  String get companyName => userInfo.value.company?.name ?? '-';

  String get departmentName =>
      userInfo.value.employee?.departement?.name ?? '-';

  String get jobPosition => userInfo.value.employee?.jobPosition?.name ?? '-';

  String get jobLevel => userInfo.value.employee?.jobLevel?.name ?? '-';

  String get joinDate => _date(userInfo.value.employee?.joinDate);

  String get signDate => _date(userInfo.value.employee?.signDate);

  /// The resign date, which the API has been seen to send as both a date and a
  /// string. The original getter type-tested it inline and fell back to the raw
  /// string when parsing failed; `asDate` handles both and a malformed value
  /// reads as absent rather than as unparsed text on the screen.
  String get resignDate {
    final raw = userInfo.value.employee?.resignDate;

    if (raw == null) {
      return '-';
    }

    return _date(DateTime.tryParse(raw.toString()));
  }

  String get bankName => userInfo.value.employee?.bankName ?? '-';

  String get bankNumber => userInfo.value.employee?.bankNumber ?? '-';

  String get bankHolder => userInfo.value.employee?.bankHolder ?? '-';

  String get basicSalary {
    final salary = userInfo.value.salaries?.basicSalary;

    return salary == null ? '-' : _rupiah.format(salary);
  }

  String get paymentType => userInfo.value.salaries?.paymentType ?? '-';

  String get approvalLine => userInfo.value.employee?.approvalLine?.name ?? '-';

  String get approvalManager =>
      userInfo.value.employee?.approvalManager?.name ?? '-';

  String get saldoCuti => userInfo.value.employee?.saldoCuti?.toString() ?? '-';

  /// Saldo cuti dengan satuannya. Sebuah "12" sendirian di kolom nilai bisa
  /// dibaca sebagai hari, jam, atau nomor urut; "12 hari" tidak bisa.
  String get saldoCutiLabel {
    final balance = userInfo.value.employee?.saldoCuti;

    return balance == null ? '-' : '$balance hari';
  }
}

class ProfileFamilyController extends ProfileSectionController {
  ProfileFamilyController({required super.repository});

  /// Tanggal lahir anggota keluarga, dalam bahasa Indonesia. Sebelumnya
  /// diformat di dalam widget baris dengan `DateFormat` tanpa locale.
  String formatBirthdate(DateTime? date) => _date(date);
}

class ProfileEducationController extends ProfileSectionController {
  ProfileEducationController({required super.repository});

  final RxList<FormalEducation> formalEducations = <FormalEducation>[].obs;
  final RxList<InformalEducationModel> informalEducations =
      <InformalEducationModel>[].obs;

  @override
  void onProfileLoaded(User user) {
    formalEducations.assignAll(user.formalEducations ?? const []);
    informalEducations.assignAll(user.informalEducations ?? const []);
  }

  Future<void> fetchEducationData() => loadProfile(refresh: true);

  String formatEducationPeriod(DateTime? startDate, DateTime? endDate) {
    final start = startDate == null ? '' : _year.format(startDate);
    final end = endDate == null ? '' : _year.format(endDate);

    if (start.isEmpty && end.isEmpty) {
      return '-';
    }

    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }

    return start.isNotEmpty ? 'Sejak $start' : 'Hingga $end';
  }
}

class ProfileExperienceController extends ProfileSectionController {
  ProfileExperienceController({required super.repository});

  final RxList<WorkExperienceModel> workExperiences =
      <WorkExperienceModel>[].obs;

  @override
  void onProfileLoaded(User user) {
    workExperiences.assignAll(user.workExperiences ?? const []);
  }

  Future<void> fetchWorkExperienceData() => loadProfile(refresh: true);

  String formatWorkPeriod(DateTime? startDate, DateTime? finishDate) {
    final start = startDate == null ? '' : _dayShortMonthYear.format(startDate);
    // An open-ended role reads as "Sekarang", as it did before.
    final finish = finishDate == null
        ? 'Sekarang'
        : _dayShortMonthYear.format(finishDate);

    if (start.isEmpty && finish.isEmpty) {
      return '-';
    }

    if (start.isNotEmpty) {
      return '$start - $finish';
    }

    return 'Hingga $finish';
  }

  String formatCertificationStatus(bool? certification) {
    if (certification == null) {
      return '-';
    }

    return certification ? 'Ya' : 'Tidak';
  }
}

class ProfilePayrollController extends GetxController
    with WidgetsBindingObserver {
  ProfilePayrollController({
    required PayrollRepository repository,
    SessionRepository? session,
  }) : _repository = repository,
       _session = session;
  final PayrollRepository _repository;
  final SessionRepository? _session;
  final slips = <Payslip>[].obs;
  final isLoading = false.obs;
  final isMoreLoading = false.obs;
  final hasMore = false.obs;
  final errorMessage = RxnString();
  final detail = Rxn<Payslip>();
  final isDetailLoading = false.obs;
  final detailError = RxnString();
  final isDownloading = false.obs;
  int _page = 1, _generation = 0, _detailGeneration = 0;
  Worker? _notifications;
  int? _selectedId;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (_session != null) {
      _notifications = ever(
        _session.notificationRevision,
        (_) => refreshSlips(),
      );
    }
    refreshSlips();
  }

  @override
  void onClose() {
    _generation++;
    _detailGeneration++;
    _notifications?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshSlips();
  }

  Future<void> refreshSlips() async {
    final generation = ++_generation;
    final token = _session?.token;
    isLoading.value = true;
    isMoreLoading.value = false;
    errorMessage.value = null;
    try {
      final result = await _repository.page();
      if (generation != _generation || token != _session?.token) return;
      slips.assignAll(result.rows);
      _page = result.currentPage;
      hasMore.value = result.hasMore;
      final selected = _selectedId;
      if (selected != null) await loadDetail(selected);
    } on ApiException catch (error) {
      if (generation == _generation && token == _session?.token) {
        errorMessage.value = error.message;
      }
    } finally {
      if (generation == _generation) isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoading.value || isMoreLoading.value || !hasMore.value) return;
    final generation = _generation;
    final token = _session?.token;
    isMoreLoading.value = true;
    try {
      final result = await _repository.page(page: _page + 1);
      if (generation != _generation || token != _session?.token) return;
      slips.addAll(result.rows);
      _page = result.currentPage;
      hasMore.value = result.hasMore;
      errorMessage.value = null;
    } on ApiException catch (error) {
      if (generation == _generation && token == _session?.token) {
        errorMessage.value = error.message;
      }
    } finally {
      if (generation == _generation) isMoreLoading.value = false;
    }
  }

  Future<void> loadDetail(int id) async {
    _selectedId = id;
    final generation = ++_detailGeneration;
    final token = _session?.token;
    detail.value = null;
    detailError.value = null;
    isDetailLoading.value = true;
    try {
      final slip = await _repository.slip(id);
      if (generation == _detailGeneration && token == _session?.token) {
        detail.value = slip;
      }
    } on ApiException catch (error) {
      if (generation == _detailGeneration && token == _session?.token) {
        detailError.value = error.message;
      }
    } finally {
      if (generation == _detailGeneration) isDetailLoading.value = false;
    }
  }

  void closeDetail() {
    _selectedId = null;
    _detailGeneration++;
    detail.value = null;
  }

  Future<({String filename, Uint8List bytes})> download(int id) async {
    final token = _session?.token;
    final pdf = await _repository.pdf(id);
    if (token != _session?.token) {
      throw const ApiException('Sesi berubah. Buka ulang slip gaji.');
    }
    return pdf;
  }
}
