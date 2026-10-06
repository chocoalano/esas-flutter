/// Setiap komponen dan setiap layar, di setiap lebar dan skala teks yang
/// benar-benar dipakai orang.
///
/// Aplikasi ini tidak punya golden test, jadi tanpa berkas ini tidak ada satu
/// pun hal di dalam suite yang akan menangkap regresi tata letak: 277 dari 302
/// tes lainnya tidak pernah membangun widget tree sama sekali, dan tiga harness
/// yang membangunnya semua menyetel `isLoading = false` sehingga kerangka muat
/// pun tidak pernah dirender.
///
/// Perkaliannya — subjek x {320, 360, 375, 412}dp x skala teks {1.0, 1.3, 1.5}
/// x {terang, gelap} — bukan kelengkapan demi kelengkapan. 320dp adalah ponsel
/// termurah yang masih dipakai di lapangan, dan skala teks 1.5 adalah setelan
/// orang yang matanya sudah tidak muda; keduanya bertemu pada label bahasa
/// Indonesia yang lebih panjang daripada padanan Inggrisnya, dan di sanalah
/// setiap `Row` yang tidak dibungkus `Expanded` akhirnya meluap.
///
/// Berkas ini sudah menemukan tujuh overflow nyata pada gelombang redesain —
/// termasuk `SliverGeometry is not valid` pada kepala bulan yang menempel —
/// dan satu lagi yang ditulis saat menutupnya. Kalau ia terasa berisik, itu
/// karena ia sedang bekerja.
library;

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/profile/data/repositories/payroll_repository.dart';
import 'package:esas/features/profile/data/models/payslip.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/theme/theme_controller.dart';
import 'package:esas/core/ui/components/app_attendance_summary.dart';
import 'package:esas/core/ui/components/app_avatar.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_button.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_data_row.dart';
import 'package:esas/core/ui/components/app_day_strip.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:esas/core/ui/components/app_metric_tile.dart';
import 'package:esas/core/ui/components/app_progress.dart';
import 'package:esas/core/ui/components/app_record_field.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/components/app_segmented_progress.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/ui/components/app_sparkline.dart';
import 'package:esas/core/ui/layout/app_breakpoints.dart';
import 'package:esas/core/ui/layout/app_responsive.dart';
import 'package:esas/features/attendance/data/models/attendance.dart';
import 'package:esas/features/attendance/data/models/attendance_history_page.dart';
import 'package:esas/features/attendance/data/models/attendance_month_totals.dart';
import 'package:esas/features/attendance/presentation/widgets/attendance_list_item.dart';
import 'package:esas/features/home/presentation/widgets/home_header.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/data/models/leave_type.dart';
import 'package:esas/features/permit/presentation/widgets/permit_list_item.dart';
import 'package:esas/features/permit/presentation/widgets/type_card_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:esas/core/services/device_info_service.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/core/ui/controllers/bottom_nav_controller.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/presentation/controllers/attendance_list_controller.dart';
import 'package:esas/features/attendance/presentation/views/attendance_list_view.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/data/services/auth_api_service.dart';
import 'package:esas/features/auth/presentation/controllers/change_password_controller.dart';
import 'package:esas/features/auth/presentation/controllers/login_controller.dart';
import 'package:esas/features/auth/presentation/views/change_password_view.dart';
import 'package:esas/features/auth/presentation/views/login_view.dart';
import 'package:esas/features/home/data/models/activity_log.dart';
import 'package:esas/features/home/data/models/announcement.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/controllers/activity_controller.dart';
import 'package:esas/features/home/presentation/controllers/announcement_controller.dart';
import 'package:esas/features/home/presentation/controllers/announcement_detail_controller.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/views/activity_view.dart';
import 'package:esas/features/home/presentation/views/announcement_detail_view.dart';
import 'package:esas/features/home/presentation/views/announcement_view.dart';
import 'package:esas/features/home/presentation/views/home_view.dart';
import 'package:esas/features/notification/data/models/notification.dart';
import 'package:esas/features/notification/data/repositories/notification_repository.dart';
import 'package:esas/features/notification/presentation/controllers/notification_controller.dart';
import 'package:esas/features/notification/presentation/views/notification_view.dart';
import 'package:esas/features/permit/data/models/schedule.dart';
import 'package:esas/features/permit/data/models/timework.dart';
import 'package:esas/features/permit/data/repositories/permit_repository.dart';
import 'package:esas/features/permit/presentation/controllers/permit_controller.dart';
import 'package:esas/features/permit/presentation/controllers/permit_create_controller.dart';
import 'package:esas/features/permit/presentation/controllers/permit_list_controller.dart';
import 'package:esas/features/permit/presentation/controllers/permit_show_controller.dart';
import 'package:esas/features/permit/presentation/views/permit_create_view.dart';
import 'package:esas/features/permit/presentation/views/permit_list_view.dart';
import 'package:esas/features/permit/presentation/views/permit_show_view.dart';
import 'package:esas/features/permit/presentation/views/permit_view.dart';
import 'package:esas/features/profile/data/models/user.dart' as profile;
import 'package:esas/features/profile/data/repositories/profile_repository.dart';
import 'package:esas/features/profile/presentation/controllers/profile_bug_report_controller.dart';
import 'package:esas/features/profile/presentation/controllers/profile_controller.dart';
import 'package:esas/features/profile/presentation/controllers/profile_section_controller.dart';
import 'package:esas/features/profile/presentation/controllers/profile_tab_controllers.dart';
import 'package:esas/features/profile/presentation/views/profile_bug_report_view.dart';
import 'package:esas/features/profile/presentation/views/profile_education_view.dart';
import 'package:esas/features/profile/presentation/views/profile_experience_view.dart';
import 'package:esas/features/profile/presentation/views/profile_family_view.dart';
import 'package:esas/features/profile/presentation/views/profile_payroll_view.dart';
import 'package:esas/features/profile/presentation/views/profile_personal_view.dart';
import 'package:esas/features/profile/presentation/views/profile_view.dart';
import 'package:esas/features/profile/presentation/views/profile_worked_view.dart';
import 'package:esas/features/setup/data/repositories/workspace_repository.dart';
import 'package:esas/features/setup/presentation/controllers/setup_controller.dart';
import 'package:esas/features/setup/presentation/views/setup_view.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermitRepository extends Mock implements PermitRepository {}

class _MockHomeRepository extends Mock implements HomeRepository {}

class _MockAttendanceRepository extends Mock implements AttendanceRepository {}

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockPayrollRepository extends Mock implements PayrollRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAuthApiService extends Mock implements AuthApiService {}

class _MockTenantContext extends Mock implements TenantContext {}

class _MockWorkspaceRepository extends Mock implements WorkspaceRepository {}

class _MockDeviceInfoService extends Mock implements DeviceInfoService {}

/// Probe sekali pakai: bangun SETIAP komponen di lib/core/ui/components pada
/// empat lebar kali tiga skala teks kali dua tema, dan pastikan tidak ada
/// exception (overflow dihitung sebagai exception di lingkungan uji).
void main() {
  setUpAll(() {
    initializeDateFormatting('id_ID');

    // `ThemeController` membuat sebuah `GetStorage` di inisialisasi fieldnya,
    // dan `GetStorage` membuka berkasnya lewat path_provider — sebuah kanal
    // platform yang tidak ada di lingkungan uji, sehingga pembukaannya gagal
    // sebagai galat asinkron yang tidak tertangani. Instansnya di-cache per
    // nama kontainer, jadi cukup dibuat sekali di sini dan kegagalan
    // pembukaannya ditelan: pembacaan berikutnya jatuh ke peta kosong dan
    // mengembalikan null, yang persis nilai yang dipakai controller ketika
    // pengguna belum pernah memilih tema.
    GetStorage().initStorage.catchError((Object _) => false);
  });

  // Teks sengaja dibuat panjang: yang meluap bukan "OK", melainkan kalimat
  // Indonesia sungguhan pada kolom sempit di skala 1.5.
  const longLabel = 'Penyesuaian jam kerja karyawan bagian produksi';

  final Attendance attendanceLate = Attendance.fromJson({
    'id': 12,
    'time_in': '08:11:00',
    'time_out': '17:32:00',
    'status_in': 'late',
    'status_out': 'on_time',
    'date_presence': '2026-08-31',
    'created_at': '2026-08-31T01:01:00.000Z',
    'user': {'name': 'Budi Santoso Wijaya Kusuma', 'nip': '1234567890'},
  });
  final Attendance attendanceOpen = Attendance.fromJson({
    'id': 13,
    'time_in': '08:00:00',
    'time_out': null,
    'status_in': 'on_time',
    'date_presence': '2026-09-01',
  });

  final Permit permitPending = Permit.fromJson({
    'id': 1,
    'permit_numbers': 'PRM-2026-0000001',
    'start_date': '2026-09-02',
    'end_date': '2026-09-05',
    'permit_type': {
      'id': 87,
      'name': 'Cuti tahunan karyawan bagian produksi',
      'code': 'ANNUAL',
      'variant': 'leave',
    },
    'approvals': [
      {'id': 1, 'user_approve': 'y'},
      {'id': 2, 'user_approve': 'w'},
      {'id': 3, 'user_approve': null},
    ],
  });

  final LeaveType leaveType = LeaveType.fromJson({
    'id': 87,
    'type': 'Cuti tahunan karyawan bagian produksi',
    'description': longLabel,
    'is_payed': true,
    'variant': 'leave',
  });

  Map<String, Widget> cases(AppPalette palette) => {
    'AppCard': const AppCard(child: Text(longLabel)),
    'AppCard.selected': const AppCard(selected: true, child: Text(longLabel)),
    'AppIconBox': const AppIconBox(icon: Icons.access_time_rounded),
    'AppBadge.small': const AppBadge(
      label: longLabel,
      tone: AppBadgeTone.warning,
      size: AppBadgeSize.small,
    ),
    'AppBadge.large': const AppBadge(
      label: longLabel,
      tone: AppBadgeTone.danger,
      size: AppBadgeSize.large,
    ),
    'AppBadge.dense': const AppBadge(label: longLabel, dense: true),
    'AppStatusDot': const AppStatusDot(color: Color(0xFF3ECF8E)),
    'AppSectionHeader': const AppSectionHeader(
      title: 'Penyesuaian shift',
      subtitle: longLabel,
      actionLabel: 'Lihat semua',
      showDivider: true,
    ),
    'AppPageTitle': const AppPageTitle(title: longLabel),
    'AppEmptyState': const AppEmptyState(
      icon: Icons.inbox_rounded,
      title: 'Belum ada pengajuan',
      message: longLabel,
      actionLabel: 'Ajukan izin',
    ),
    'AppErrorState': const AppErrorState(message: longLabel),
    'AppErrorState.compact': const AppErrorState(
      message: longLabel,
      compact: true,
    ),
    'AppButton.filled': const AppButton(label: longLabel, onPressed: null),
    'AppButton.busy': const AppButton(
      label: longLabel,
      onPressed: null,
      busy: true,
      icon: Icons.send_rounded,
    ),
    'AppButton.outlined': const AppButton(
      label: longLabel,
      onPressed: null,
      variant: AppButtonVariant.outlined,
    ),
    'AppButton.text': const AppButton(
      label: longLabel,
      onPressed: null,
      variant: AppButtonVariant.text,
      expand: false,
    ),
    'AppAvatar': const AppAvatar(userName: 'Budi Santoso Wijaya'),
    'AppAvatar.badge': const AppAvatar(
      userName: 'Budi',
      badge: AppStatusDot(color: Color(0xFF3ECF8E)),
    ),
    'AppLinearProgress': const AppLinearProgress(
      value: 0.004,
      label: longLabel,
    ),
    'AppLinearProgress.full': const AppLinearProgress(
      value: 1.0,
      label: 'Cuti',
    ),
    'AppSparkline': const AppSparkline(
      values: [1, null, 3, 4, null, 2, 5],
      summary: 'Tren tujuh hari terakhir naik',
    ),
    'AppSparkline.allNull': const AppSparkline(
      values: [null, null, null],
      summary: 'Tidak ada data',
    ),
    'AppDayStrip': AppDayStrip(
      days: [
        palette.success,
        palette.warning,
        palette.danger,
        palette.success,
        palette.success,
        palette.neutral,
        palette.neutral,
      ],
      summary: 'Lima hadir, satu terlambat, satu alpa',
    ),
    'AppSegmentedProgress': AppSegmentedProgress(
      total: 12,
      filled: 5,
      tone: palette.success,
    ),
    'AppDataRow': const AppDataRow(
      label: 'Jam masuk penyesuaian',
      value: '08:00',
      delta: '+11 menit',
    ),
    'AppDataRow.long': const AppDataRow(label: longLabel, value: longLabel),
    'AppMetricTile': const AppMetricTile(
      label: longLabel,
      value: '08:11',
      unit: 'WIB',
      icon: Icons.login_rounded,
      delta: '+11 m',
      caption: longLabel,
      trend: [1, 2, null, 4],
      trendSummary: 'Naik',
    ),
    'AppMetricTile.count': const AppMetricTile.count(
      label: 'Sisa cuti',
      count: 12,
      unit: 'hari',
      icon: Icons.beach_access_rounded,
    ),
    'AttendanceSummaryPanel': const AttendanceSummaryPanel(
      checkInTime: '08:11',
      checkOutTime: '17:32',
      duration: '8j 45m',
      status: AttendanceStatus.checkedOut,
    ),
    'AttendanceSummaryPanel.absent': const AttendanceSummaryPanel(
      checkInTime: '--:--',
      checkOutTime: null,
      duration: null,
      status: AttendanceStatus.absent,
    ),
    'AttendanceSummaryPanel.history': AttendanceSummaryPanel(
      checkInTime: '08:11',
      checkOutTime: '17:32',
      duration: '8j 45m',
      status: AttendanceStatus.checkedIn,
      onViewHistory: () {},
    ),
    'AppSkeletonRow': const AppSkeletonRow(),
    'PermitSkeletonRow': const PermitSkeletonRow(),
    'AttendanceSkeletonRow': const AttendanceSkeletonRow(),
    'AppSkeleton.bare': const AppSkeleton(width: 80),
    // --- Gelombang 4: potongan layar yang tidak butuh controller hidup. ---
    'AppRecordField': const AppRecordField(label: longLabel, value: longLabel),
    'AppRecordField.mono': const AppRecordField(
      label: 'Nomor induk karyawan',
      value: '1234567890123456',
      mono: true,
    ),
    'AppRecordField.blank': const AppRecordField(label: longLabel, value: ''),
    'AppRecordFieldPair': const AppRecordFieldPair(
      first: AppRecordField(label: longLabel, value: '08:00'),
      second: AppRecordField(label: longLabel, value: '17:30'),
    ),
    'AppRecordFieldPair.single': const AppRecordFieldPair(
      first: AppRecordField(label: longLabel, value: longLabel),
    ),
    'HomeHeader': const HomeHeader(
      userName: 'Budi Santoso Wijaya Kusumaningrat',
      userAvatarUrl: '',
    ),
    // Menggantikan subjek `HomeDateStrip`, yang dibubarkan menjadi baris ketiga
    // di dalam kepala Beranda: yang perlu tetap dipompa adalah baris tanggalnya,
    // bukan kotak yang dulu memuatnya.
    'HomeHeader.date': const HomeHeader(
      userName: 'Budi Santoso Wijaya Kusumaningrat',
      userAvatarUrl: '',
      date: 'Rabu, 3 September 2026',
      notificationCount: 99,
    ),
    'AttendanceListItem.late': AttendanceListItem(
      attendance: attendanceLate,
      onTap: () {},
    ),
    'AttendanceListItem.open': AttendanceListItem(
      attendance: attendanceOpen,
      onTap: () {},
    ),
    'PermitListItem': PermitListItem(permit: permitPending),
    'LeaveTypeRow': LeaveTypeRow(item: leaveType, onTap: () {}),
    'LeaveTypePanel': LeaveTypePanel(
      children: [
        LeaveTypeRow(item: leaveType, onTap: () {}),
        LeaveTypeRow(item: leaveType, onTap: () {}),
      ],
    ),
    // --- Gelombang 5: primitif tata letak responsif. ---
    'AppPageInset': const AppPageInset(child: Text(longLabel)),
    'AppPageInset.bleed': const AppPageInset(
      bleed: true,
      child: Text(longLabel),
    ),
    'AppContentClamp': const AppContentClamp(child: Text(longLabel)),
    'AppTwoColumn': const AppTwoColumn(
      primary: [
        Text(longLabel),
        AppCard(child: Text(longLabel)),
      ],
      secondary: [
        Text(longLabel),
        AppCard(child: Text(longLabel)),
      ],
    ),
  };

  // Matriks ukuran. Keempat pasangan lama dipertahankan apa adanya — lebar yang
  // sama, tinggi 800 yang sama — supaya tidak satu pun konfigurasi yang sudah
  // ada bergeser kelas atau berganti cabang; yang bertambah hanyalah pasangan
  // baru di sampingnya.
  //
  // Empat pasangan baru dipilih karena masing-masing membuktikan satu hal yang
  // tidak dibuktikan pasangan lain. 915x412 adalah ponsel dalam lanskap, satu-
  // satunya kasus yang membuktikan bahwa ambang TINGGI dibaca sebelum ambang
  // lebar; tanpa aturan itu ia akan menerima tata letak tablet di layar
  // setinggi 412dp. 600x960 duduk tepat di ambang 600 dan mewakili tablet tujuh
  // inci potret sekaligus split-screen vertikal. 800x1280 dan 1280x800 sengaja
  // perangkat yang SAMA diputar: pasangan itulah yang membuktikan bahwa tablet
  // yang berputar tidak berpindah kelas, dan yang kedua sekaligus satu-satunya
  // yang menguji jepitan lebar baca 1080dp.
  //
  // Enam pasangan berikutnya menutup lubang yang tersisa, dan dua di antaranya
  // memalukan untuk dibiarkan kosong. 390x844 adalah perangkat yang dipakai
  // pemilik produk saat mengirim tangkapan layar yang memicu redesain ini —
  // lebar yang paling sering dipegang orang, dan satu-satunya lebar yang
  // benar-benar pernah dilihat gagal, tetapi tidak pernah dipompa. 768x1024 dan
  // 1024x768 adalah iPad sepuluh inci di kedua orientasi, dua ukuran tablet
  // yang paling banyak beredar dan yang tidak diwakili oleh 800x1280 karena
  // keduanya jatuh di kelas yang berbeda satu sama lain. 844x390 melengkapi
  // 390x844 sebagai perangkat SAMA yang diputar, sehingga klaim rotasi tidak
  // hanya dibuktikan pada tablet. 412x915 adalah ponsel Android jangkung dalam
  // potret penuh, yang berbeda dari 412x800 justru pada tingginya. 1024x1366
  // adalah tablet dua belas inci potret, satu-satunya ukuran yang lebar DAN
  // jangkung sekaligus.
  const List<Size> screenSizes = <Size>[
    Size(320, 800),
    Size(360, 800),
    Size(375, 800),
    Size(390, 844),
    Size(412, 800),
    Size(412, 915),
    Size(844, 390),
    Size(915, 412),
    Size(600, 960),
    Size(768, 1024),
    Size(800, 1280),
    Size(1024, 768),
    Size(1024, 1366),
    Size(1280, 800),
  ];

  // Komponen tidak membaca kelas ukuran dan tidak bercabang per kelas, jadi
  // memompanya di kedelapan pasangan hanya membeli waktu jalan. Yang perlu
  // dibuktikan cuma bahwa mereka selamat ketika batasannya lebar sekaligus
  // pendek, dan 1280x800 adalah yang terlebar sekaligus terpendek dari keempat
  // pasangan baru — jadi ia kasus komponen yang paling ketat. Skala 1.3 di
  // sana ikut dilewati: ia terjepit di antara dua skala yang sudah dijalankan
  // dan tidak pernah menjadi satu-satunya yang gagal.
  const List<double> allScales = <double>[1.0, 1.3, 1.5];
  const List<({Size size, List<double> scales})> componentSizes =
      <({Size size, List<double> scales})>[
        (size: Size(320, 800), scales: allScales),
        (size: Size(360, 800), scales: allScales),
        (size: Size(375, 800), scales: allScales),
        (size: Size(412, 800), scales: allScales),
        (size: Size(1280, 800), scales: <double>[1.0, 1.5]),
      ];

  // Aturan kelas ukuran diuji tanpa satu widget pun. `AppLayout.resolve` sengaja
  // dibuat fungsi murni supaya bagian yang paling mudah salah — urutan cabang —
  // bisa dibuktikan dengan sepuluh baris, bukan dengan menebak dari tangkapan
  // layar.
  group('AppLayout', () {
    test('ukuran probe layar menutup keempat kelas', () {
      expect(
        screenSizes.map((Size s) => AppLayout.resolve(s).layoutClass).toSet(),
        AppLayoutClass.values.toSet(),
      );
    });

    test('ambang tinggi dibaca sebelum ambang lebar', () {
      // Ponsel dalam lanskap: cukup lebar untuk lolos ambang tablet, terlalu
      // pendek untuk memikul kolom setinggi penuh.
      expect(
        AppLayout.resolve(const Size(915, 412)).layoutClass,
        AppLayoutClass.compactLandscape,
      );
      expect(
        AppLayout.resolve(const Size(1280, 599)).layoutClass,
        AppLayoutClass.compactLandscape,
      );
      // Satu piksel lebih tinggi dan ia benar-benar tablet.
      expect(
        AppLayout.resolve(const Size(1280, 600)).layoutClass,
        AppLayoutClass.expanded,
      );
    });

    test('lebar di bawah 600 tetap compact, sependek apa pun layarnya', () {
      for (final Size size in const <Size>[
        Size(320, 800),
        Size(412, 915),
        Size(599, 300),
      ]) {
        expect(AppLayout.resolve(size).layoutClass, AppLayoutClass.compact);
      }
    });

    test('ambang lebar persis di angkanya', () {
      expect(
        AppLayout.resolve(const Size(599, 960)).layoutClass,
        AppLayoutClass.compact,
      );
      expect(
        AppLayout.resolve(const Size(600, 960)).layoutClass,
        AppLayoutClass.medium,
      );
      expect(
        AppLayout.resolve(const Size(839, 960)).layoutClass,
        AppLayoutClass.medium,
      );
      expect(
        AppLayout.resolve(const Size(840, 960)).layoutClass,
        AppLayoutClass.expanded,
      );
    });

    test('tablet yang diputar tidak mengubah bentuk tata letaknya', () {
      final AppLayoutMetrics portrait = AppLayout.resolve(
        const Size(800, 1280),
      );
      final AppLayoutMetrics landscape = AppLayout.resolve(
        const Size(1280, 800),
      );

      // Kelasnya boleh naik satu tingkat; yang tidak boleh berubah adalah
      // bentuknya — tetap dua kolom, dan tetap tidak ada yang menerobos margin.
      expect(portrait.twoColumn, isTrue);
      expect(landscape.twoColumn, isTrue);
      expect(portrait.heroBleeds, isFalse);
      expect(landscape.heroBleeds, isFalse);
    });

    test('hanya compact yang mengizinkan bagian menerobos margin', () {
      for (final Size size in screenSizes) {
        final AppLayoutMetrics layout = AppLayout.resolve(size);
        expect(
          layout.heroBleeds,
          layout.layoutClass == AppLayoutClass.compact,
          reason: '${size.width}x${size.height}',
        );
      }
    });

    test('lebar baca dijepit hanya ketika layarnya memang melebihi', () {
      expect(
        AppLayout.resolve(const Size(1280, 800)).contentMaxWidth,
        AppBreakpoints.readingMax,
      );
      expect(AppLayout.resolve(const Size(800, 1280)).contentMaxWidth, isNull);
      expect(AppLayout.resolve(const Size(360, 800)).contentMaxWidth, isNull);
    });

    test('dua ukuran di kelas yang sama menghasilkan nilai yang setara', () {
      // Kesetaraan struktural record inilah yang membuat sebuah widget bisa
      // membandingkan nilai lama dan baru untuk tahu apakah rotasi benar-benar
      // mengubah kelasnya atau hanya menggeser beberapa piksel.
      expect(
        AppLayout.resolve(const Size(1000, 900)),
        AppLayout.resolve(const Size(1280, 800)),
      );
      expect(
        AppLayout.resolve(const Size(360, 800)),
        isNot(AppLayout.resolve(const Size(800, 1280))),
      );
    });
  });

  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    final palette = theme.palette;
    final mode = dark ? 'gelap' : 'terang';

    for (final entry in componentSizes) {
      final Size size = entry.size;
      for (final scale in entry.scales) {
        cases(palette).forEach((name, widget) {
          testWidgets('$name @ ${size.width.toInt()}x${size.height.toInt()}dp '
              'x$scale $mode', (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final _ErrorTrap trap = _ErrorTrap();

            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: MediaQuery(
                  // `size` ikut diberikan supaya primitif yang membaca
                  // `MediaQuery.sizeOf` melihat lebar yang sama dengan yang
                  // dipasang ke `tester.view`, bukan `Size.zero` bawaan
                  // `MediaQueryData` kosong.
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    // SingleChildScrollView menyerap luapan VERTIKAL yang
                    // memang wajar di layar 800px pada skala 1.5; yang diburu
                    // probe ini adalah luapan HORIZONTAL.
                    body: SingleChildScrollView(child: widget),
                  ),
                ),
              ),
            );
            // Jangan pernah pumpAndSettle: denyut skeleton berulang selamanya.
            await tester.pump(const Duration(milliseconds: 400));
            trap.assertClean(tester);
          });
        });
      }
    }
  }

  // ------------------------------------------------------------------
  // Gelombang 4: LAYAR penuh. Setiap layar yang bisa dibangun tanpa
  // controller hidup — repositori dipalsukan, keadaan diisi tangan.
  // Dikecualikan: AttendanceView (onInit membuat MobileScannerController,
  // sebuah plugin kamera yang tidak ada di lingkungan uji) dan SplashView
  // (IntroductionScreen memulai timer navigasi ke rute nyata).
  // ------------------------------------------------------------------

  final profile.User richUser = profile.User.fromJson({
    'id': 7,
    'name': 'Budi Santoso Wijaya Kusumaningrat',
    'nip': '1234567890123456',
    'email': 'budi.santoso.wijaya@perusahaan.co.id',
    'company': {'id': 1, 'name': 'PT Sumber Rejeki Makmur Sentosa'},
    'departement': {'id': 2, 'name': 'Produksi Perakitan Lini Dua'},
    'details': {
      'phone': '081234567890',
      'gender': 'l',
      'blood_type': 'o',
      'birth_place': 'Kabupaten Bandung Barat',
      'birth_date': '1995-04-17',
      'marital_status': 'menikah',
      'religion': 'islam',
      'no_ktp': '3204170404950001',
      'no_kk': '3204170404950002',
      'status': 'permanent',
      'join_date': '2019-02-01',
      'resign_date': null,
      'bank_name': 'Bank Negara Indonesia',
      'bank_number': '0123456789',
    },
    'address': {
      'citizen_address': 'Jalan Raya Padalarang Nomor 145 RT 04 RW 09',
      'residential_address': 'Jalan Raya Padalarang Nomor 145 RT 04 RW 09',
    },
    'salaries': {
      'basic_salary': 5500000,
      'presence_allowance': 250000,
      'transport_allowance': 300000,
      'meal_allowance': 400000,
      'functional_allowance': 150000,
    },
    'families': [
      {
        'name': 'Siti Rahmawati Nuraini',
        'relationship': 'istri',
        'birth_date': '1997-08-21',
        'job': 'Ibu rumah tangga',
      },
    ],
    'formal_educations': [
      {
        'institution': 'Universitas Pendidikan Indonesia Bandung',
        'major': 'Teknik Mesin Produksi',
        'score': '3.42',
        'start_year': '2013',
        'end_year': '2017',
      },
    ],
    'informal_educations': [
      {
        'institution': 'Balai Latihan Kerja Kabupaten Bandung Barat',
        'organizer': 'Kementerian Ketenagakerjaan',
        'start_date': '2018-01-05',
        'end_date': '2018-03-05',
        'description': 'Pelatihan pengelasan tingkat lanjut',
      },
    ],
    'work_experiences': [
      {
        'company_name': 'PT Karya Bersama Indonesia Sejahtera',
        'position': 'Operator Mesin Bubut Senior',
        'start_date': '2017-06-01',
        'end_date': '2019-01-31',
        'description': 'Mengoperasikan mesin bubut dan mengawasi mutu hasil.',
      },
    ],
  });

  final List<Announcement> announcements = [
    Announcement.fromJson({
      'id': 1,
      'title': 'Penyesuaian jam kerja selama bulan Ramadan tahun ini',
      'excerpt':
          'Jam masuk dimajukan menjadi 07.30 dan jam pulang menjadi 16.00 '
          'untuk seluruh karyawan bagian produksi.',
      'content': '<p>Jam masuk dimajukan menjadi 07.30.</p>',
      'published_by': 'Departemen Sumber Daya Manusia',
      'created_at': '2026-09-01T02:00:00.000Z',
    }),
    Announcement.fromJson({
      'id': 2,
      'title': 'Libur',
      'excerpt': null,
      'created_at': '2026-08-20T02:00:00.000Z',
    }),
  ];

  final List<ActivityLog> activities = [
    ActivityLog.fromJson({
      'id': 1,
      'user_id': 7,
      'method': 'POST',
      'url': '/api/v1/permits',
      'action': 'created',
      'model_type': 'App\\Models\\Permit',
      'model_id': 12,
      'ip_address': '10.20.30.40',
      'user_agent': 'ESAS/2.0 (Android 14)',
      'created_at': '2026-09-01T02:00:00.000Z',
    }),
  ];

  final List<NotificationModel> notifications = [
    NotificationModel.fromJson({
      'id': 'a1',
      'type': 'App\\Notifications\\PermitApproved',
      'notifiable_type': 'App\\Models\\User',
      'notifiable_id': 7,
      'data': {
        'title': 'Pengajuan cuti tahunan Anda telah disetujui atasan',
        'message':
            'Pengajuan nomor PRM-2026-0000001 untuk 2 sampai 5 September '
            'sudah disetujui oleh Kepala Departemen Produksi.',
        'url': '/permits/1',
      },
      'read_at': null,
      'created_at': '2026-09-01T02:00:00.000Z',
      'updated_at': '2026-09-01T02:00:00.000Z',
      'notifiable': {'id': 7, 'name': 'Budi', 'nip': '123'},
    }),
    NotificationModel.fromJson({
      'id': 'a2',
      'data': {'title': 'Absen', 'message': 'Selesai.', 'url': ''},
      'read_at': '2026-09-01T03:00:00.000Z',
      'created_at': '2026-09-01T02:00:00.000Z',
      'notifiable': {'id': 7},
    }),
  ];

  /// Beranda dalam satu keadaan.
  ///
  /// [failure] menggantikan sebuah bool karena keadaan galat dasbor BUKAN satu
  /// keadaan: statusnya yang memilih tombolnya, dan ketiga cabangnya menggambar
  /// bentuk yang berbeda. Transport (tanpa status) dan 401 menggambar tombol,
  /// 403 sengaja tidak menggambar tombol sama sekali karena mencoba lagi tidak
  /// pernah bisa memperbaiki izin — jadi barisnya lebih pendek satu tombol, dan
  /// itu tata letak tersendiri yang perlu dipompa seperti yang lain.
  Widget buildHome({
    required bool loading,
    required bool error,
    ApiException? failure,
  }) {
    final repo = _MockHomeRepository();
    when(() => repo.userName).thenReturn('Budi Santoso Wijaya Kusumaningrat');
    when(() => repo.userAvatar).thenReturn('');
    when(() => repo.todayAttendance()).thenAnswer(
      (_) async => const DashboardTimes(
        timeIn: '08:11',
        timeOut: '17:32',
        statusIn: 'Terlambat 11 menit',
        statusOut: 'Tepat waktu',
        scheduleIn: '08:00',
        scheduleOut: '17:00',
        scheduleName: 'Pagi',
      ),
    );
    when(() => repo.activeAnnouncements()).thenAnswer((_) async => []);
    when(
      () => repo.leaveBalances(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => []);
    when(
      () => repo.monthSummary(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => const MonthSummary(workedDays: 21, lateCount: 3));
    when(
      () => repo.recentPermits(limit: any(named: 'limit')),
    ).thenAnswer((_) async => <Permit>[]);

    final controller = HomeController(repository: repo);
    Get.put<HomeController>(controller);
    Get.put<BottomNavController>(
      BottomNavController(destinations: const ['/a', '/b', '/c', '/d', '/e']),
    );

    controller.userName.value = 'Budi Santoso Wijaya Kusumaningrat';
    controller.currentDate.value = 'Rabu, 2 September 2026';
    controller.isLoading.value = loading;
    controller.hasLoaded.value = !loading;

    if (error) {
      // Baku: kegagalan transport tanpa status, yang paling sering terjadi di
      // lapangan, dan yang paling tinggi keadaan galatnya di layar.
      final ApiException reason =
          failure ??
          const ApiException(
            'Tidak ada koneksi internet. Periksa jaringan Anda.',
            code: 'network_unreachable',
          );

      controller.attendanceError.value = reason;
      controller.announcementError.value = reason;
      controller.leaveError.value = reason;
      controller.summaryError.value = reason;
    } else {
      controller.timeIn.value = '08:11';
      controller.timeOut.value = '17:32';
      controller.statusIn.value = 'Terlambat 11 menit';
      controller.statusOut.value = 'Tepat waktu';
      controller.scheduleIn.value = '08:00';
      controller.scheduleOut.value = '17:00';
      controller.shiftName.value = 'Pagi';
      controller.announcements.assignAll(announcements);
      controller.leaveBalances.assignAll(const [
        LeaveBalance(
          code: 'ANNUAL',
          label: 'Cuti tahunan karyawan tetap',
          remaining: 8,
          quota: 12,
        ),
        LeaveBalance(code: 'SICK', label: 'Sakit', remaining: 0, quota: 14),
      ]);
      controller.monthSummary.value = const MonthSummary(
        workedDays: 21,
        lateCount: 3,
      );
    }

    return const HomeView();
  }

  PermitRepository stubbedPermitRepository() {
    final repo = _MockPermitRepository();
    when(() => repo.leaveTypes()).thenAnswer((_) async => [leaveType]);
    when(
      () => repo.list(
        typeId: any(named: 'typeId'),
        page: any(named: 'page'),
        perPage: any(named: 'perPage'),
        inbox: any(named: 'inbox'),
      ),
    ).thenAnswer((_) async => [permitPending]);
    when(() => repo.detail(any())).thenAnswer((_) async => permitPending);
    when(
      () => repo.formData(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => PermitFormData(
        schedules: [
          Schedule.fromJson({
            'id': 8,
            'work_day': '2026-09-02',
            'shift': 'Pagi',
            'in': '08:00:00',
            'out': '17:00:00',
          }),
        ],
        shifts: [
          Timework.fromJson({
            'id': 3,
            'name': 'Pagi',
            'in': '07:00',
            'out': '15:00',
          }),
          Timework.fromJson({
            'id': 5,
            'name': 'Malam',
            'in': '23:00',
            'out': '07:00',
          }),
        ],
        from: DateTime(2026, 9, 2),
        to: DateTime(2026, 10, 2),
      ),
    );
    when(() => repo.currentUserId).thenReturn(7);
    return repo;
  }

  ProfileRepository stubbedProfileRepository() {
    final repo = _MockProfileRepository();
    when(
      () => repo.currentUser(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => richUser);
    when(() => repo.attendanceSummary()).thenAnswer(
      (_) async => (attendance: 21, late: 3, onTime: 18, points: 87.5),
    );
    return repo;
  }

  T putSection<T extends ProfileSectionController>(T controller) {
    Get.put<T>(controller);
    controller.userInfo.value = richUser;
    controller.isLoading.value = false;
    return controller;
  }

  Map<String, Widget Function()> screens() => {
    'HomeView.data': () => buildHome(loading: false, error: false),
    'HomeView.loading': () => buildHome(loading: true, error: false),
    'HomeView.error': () => buildHome(loading: false, error: true),
    // 401: kalimatnya milik kita, tombolnya "Masuk kembali". Inilah keadaan
    // yang terlihat di tangkapan layar dasbor sungguhan, dan sebelum baris ini
    // ada ia tidak pernah dipompa pada satu ukuran pun.
    'HomeView.sessionExpired': () => buildHome(
      loading: false,
      error: true,
      failure: const ApiException(
        'Sesi ini dibuat sebelum fitur tersebut ada. '
        'Masuk kembali untuk melanjutkan.',
        status: 401,
      ),
    ),
    // 403: satu-satunya keadaan galat yang sengaja TIDAK punya tombol, jadi
    // barisnya berbentuk lain dan pantas dipompa sendiri.
    'HomeView.forbidden': () => buildHome(
      loading: false,
      error: true,
      failure: const ApiException('Tidak diizinkan.', status: 403),
    ),
    'PermitView': () {
      final controller = PermitController(
        repository: stubbedPermitRepository(),
      );
      Get.put<PermitController>(controller);
      Get.put<BottomNavController>(
        BottomNavController(destinations: const ['/a', '/b', '/c', '/d', '/e']),
      );
      controller.isLoading.value = false;
      controller.leaveTypes.assignAll([leaveType]);
      return const PermitView();
    },
    'PermitListView': () {
      final controller = PermitListController(
        repository: stubbedPermitRepository(),
      );
      Get.put<PermitListController>(controller);
      controller.isLoading.value = false;
      controller.hasMore.value = false;
      controller.permits.assignAll([permitPending]);
      return const PermitListView();
    },
    'PermitListView.empty': () {
      final controller = PermitListController(
        repository: stubbedPermitRepository(),
      );
      Get.put<PermitListController>(controller);
      controller.isLoading.value = false;
      controller.hasMore.value = false;
      return const PermitListView();
    },
    'PermitShowView': () {
      final controller = PermitShowController(
        repository: stubbedPermitRepository(),
      );
      Get.put<PermitShowController>(controller);
      controller.permit.value = permitPending;
      controller.isLoading.value = false;
      return const PermitShowView();
    },
    'PermitCreateView': () {
      final controller = PermitCreateController(
        repository: stubbedPermitRepository(),
      );
      Get.put<PermitCreateController>(controller);
      controller.createType.value = leaveType;
      return const PermitCreateView();
    },
    'AttendanceListView': () {
      final repo = _MockAttendanceRepository();
      when(
        () => repo.history(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer(
        (_) async => AttendanceHistoryPage(
          rows: [attendanceLate, attendanceOpen],
          monthTotals: [
            AttendanceMonthTotals(
              month: DateTime(2026, 9),
              recordedDays: 2,
              lateDays: 1,
              averageClockIn: '08:05',
            ),
          ],
        ),
      );
      final controller = AttendanceListController(repository: repo);
      Get.put<AttendanceListController>(controller);
      controller.isLoading.value = false;
      controller.hasMore.value = false;
      controller.attendanceList.assignAll([attendanceLate, attendanceOpen]);
      return const AttendanceListView();
    },
    'NotificationView': () {
      final repo = _MockNotificationRepository();
      when(
        () => repo.page(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          unreadOnly: any(named: 'unreadOnly'),
        ),
      ).thenAnswer(
        (_) async => NotificationPage(rows: notifications, unreadCount: 1),
      );
      final controller = NotificationController(repository: repo);
      Get.put<NotificationController>(controller);
      Get.put<BottomNavController>(
        BottomNavController(destinations: const ['/a', '/b', '/c', '/d', '/e']),
      );
      controller.isLoading.value = false;
      controller.hasMore.value = false;
      controller.notifications.assignAll(notifications);
      return const NotificationView();
    },
    'ActivityView': () {
      final repo = _MockHomeRepository();
      when(() => repo.recentActivity()).thenAnswer((_) async => activities);
      final controller = ActivityController(repository: repo);
      Get.put<ActivityController>(controller);
      controller.isLoading.value = false;
      controller.hasMore.value = false;
      controller.lists.assignAll(activities);
      return const ActivityView();
    },
    'AnnouncementView': () {
      final repo = _MockHomeRepository();
      when(
        () => repo.announcements(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
        ),
      ).thenAnswer((_) async => announcements);
      final controller = AnnouncementController(repository: repo);
      Get.put<AnnouncementController>(controller);
      controller.isLoading.value = false;
      controller.hasMore.value = false;
      controller.lists.assignAll(announcements);
      return const AnnouncementView();
    },
    'AnnouncementDetailView': () {
      final repo = _MockHomeRepository();
      when(
        () => repo.announcement(any()),
      ).thenAnswer((_) async => announcements.first);
      final controller = AnnouncementDetailController(repository: repo);
      Get.put<AnnouncementDetailController>(controller);
      controller.detail.value = announcements.first;
      controller.isLoading.value = false;
      return const AnnouncementDetailView();
    },
    'ProfileView': () {
      final auth = _MockAuthRepository();
      when(() => auth.user).thenReturn(null);
      final tenant = _MockTenantContext();
      when(() => tenant.tenant).thenReturn('sumber-rejeki');
      final controller = ProfileController(
        repository: stubbedProfileRepository(),
        auth: auth,
        tenantContext: tenant,
      );
      Get.put<ProfileController>(controller);
      Get.put<BottomNavController>(
        BottomNavController(destinations: const ['/a', '/b', '/c', '/d', '/e']),
      );
      // Baris pengubah tema duduk jauh di bawah lipatan. Pada layar setinggi
      // 800dp daftar malas ProfileView tidak pernah sampai membangunnya, jadi
      // ketiadaan controller ini tidak pernah terlihat; pada viewport tablet
      // yang lebih tinggi ia terbangun dan `Get.find` gagal.
      Get.put<ThemeController>(ThemeController());
      controller.name.value = 'Budi Santoso Wijaya Kusumaningrat';
      controller.jobTitle.value = 'Operator Mesin Bubut Senior Lini Dua';
      controller.status.value = 'Karyawan tetap';
      controller.isLoadingInitial.value = false;
      controller.late.value = 3;
      controller.attendance.value = 21;
      controller.unlate.value = 18;
      controller.points.value = 87.5;
      return const ProfileView();
    },
    'ProfilePersonalView': () {
      putSection(
        ProfilePersonalController(repository: stubbedProfileRepository()),
      );
      return const ProfilePersonalView();
    },
    'ProfileWorkedView': () {
      putSection(
        ProfileWorkedController(repository: stubbedProfileRepository()),
      );
      return const ProfileWorkedView();
    },
    'ProfileFamilyView': () {
      putSection(
        ProfileFamilyController(repository: stubbedProfileRepository()),
      );
      return const ProfileFamilyView();
    },
    'ProfileEducationView': () {
      putSection(
        ProfileEducationController(repository: stubbedProfileRepository()),
      );
      return const ProfileEducationView();
    },
    'ProfileExperienceView': () {
      putSection(
        ProfileExperienceController(repository: stubbedProfileRepository()),
      );
      return const ProfileExperienceView();
    },
    'ProfilePayrollView': () {
      final repository = _MockPayrollRepository();
      when(() => repository.page()).thenAnswer(
        (_) async => PayslipPage.fromJson({
          'data': [],
          'current_page': 1,
          'last_page': 1,
        }),
      );
      Get.put<ProfilePayrollController>(
        ProfilePayrollController(repository: repository),
      );
      return const ProfilePayrollView();
    },
    'ProfileBugReportView': () {
      Get.put<ProfileBugReportController>(
        ProfileBugReportController(repository: stubbedProfileRepository()),
      );
      return const ProfileBugReportView();
    },
    'LoginView': () {
      // With the Google button: it is the taller of the two layouts, and the
      // one an overflow would show up in.
      final auth = _MockAuthRepository();
      when(() => auth.canSignInWithGoogle).thenReturn(true);
      Get.put<LoginController>(
        LoginController(
          authRepository: auth,
          deviceInfo: _MockDeviceInfoService(),
        ),
      );
      return const LoginView();
    },
    'ChangePasswordView': () {
      Get.put<ChangePasswordController>(
        ChangePasswordController(api: _MockAuthApiService()),
      );
      return const ChangePasswordView();
    },
    'SetupView': () {
      final repo = _MockWorkspaceRepository();
      when(() => repo.domain).thenReturn('perusahaan.co.id');
      when(() => repo.workspace).thenReturn('sumber-rejeki');
      when(() => repo.subdomainMode).thenReturn(true);
      when(() => repo.isConfigured).thenReturn(true);
      Get.put<SetupController>(SetupController(repository: repo));
      return const SetupView();
    },
  };

  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    final mode = dark ? 'gelap' : 'terang';

    for (final size in screenSizes) {
      for (final scale in allScales) {
        screens().forEach((name, build) {
          testWidgets(
            'LAYAR $name @ ${size.width.toInt()}x${size.height.toInt()}dp '
            'x$scale $mode',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1.0;
              addTearDown(tester.view.reset);
              addTearDown(Get.reset);

              Get.testMode = true;

              final _ErrorTrap trap = _ErrorTrap();

              final Widget screen = build();

              await tester.pumpWidget(
                GetMaterialApp(
                  theme: theme,
                  locale: const Locale('id', 'ID'),
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [Locale('id', 'ID')],
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child ?? const SizedBox.shrink(),
                  ),
                  home: screen,
                ),
              );

              await tester.pump(const Duration(milliseconds: 400));
              trap.assertClean(tester);
            },
          );
        });
      }
    }
  }
}

/// Perangkap galat render.
///
/// Menangkap SEMUA galat, bukan hanya yang pertama seperti `takeException`,
/// dan menyimpan keterangan lengkapnya — nama widget dan barisnya — supaya
/// laporan probe menunjuk berkas, bukan sekadar jumlah piksel. Handler asli
/// WAJIB dikembalikan sebelum `fail()` dipanggil, kalau tidak binding uji
/// menegaskan bahwa sebuah tes membajak `FlutterError.onError`.
class _ErrorTrap {
  _ErrorTrap() : _previous = FlutterError.onError {
    FlutterError.onError = _details.add;
  }

  final void Function(FlutterErrorDetails)? _previous;
  final List<FlutterErrorDetails> _details = <FlutterErrorDetails>[];

  void assertClean(WidgetTester tester) {
    FlutterError.onError = _previous;
    tester.takeException();

    if (_details.isEmpty) return;

    fail(_details.map((FlutterErrorDetails d) => d.toString()).join('\n\n'));
  }
}
