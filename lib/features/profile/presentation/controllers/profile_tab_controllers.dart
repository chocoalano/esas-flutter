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

/// The payroll tab has no data source yet.
///
/// It was an empty class with three commented-out lifecycle overrides. Kept as a
/// placeholder so the route keeps working; the endpoint it needs is one of the
/// eighteen the backend owes (`06-api-migration-map.md`).
class ProfilePayrollController extends GetxController {
  ProfilePayrollController();
}
