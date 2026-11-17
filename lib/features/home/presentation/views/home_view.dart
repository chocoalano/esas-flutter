import 'package:esas/core/config/asset_url.dart';
import 'package:esas/core/registry/module_registry.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/components/custom_bottom_navbar.dart';
import 'package:esas/core/ui/controllers/bottom_nav_controller.dart';
import 'package:esas/core/ui/dialogs/app_dialogs.dart';
import 'package:esas/core/ui/layout/app_breakpoints.dart';
import 'package:esas/core/ui/layout/app_responsive.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/features/home/presentation/widgets/announcement_carousel.dart';
import 'package:esas/features/home/presentation/widgets/enterprise_services_grid.dart';
import 'package:esas/features/home/presentation/widgets/home_header.dart';
import 'package:esas/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:esas/features/home/presentation/widgets/home_recent_activity.dart';
import 'package:esas/features/home/presentation/widgets/home_leave_balance.dart';
import 'package:esas/features/home/presentation/widgets/home_monthly_snapshot.dart';
import 'package:esas/features/home/presentation/widgets/home_skeleton.dart';
import 'package:esas/features/home/presentation/widgets/today_timeline.dart';
import 'package:esas/features/home/presentation/widgets/today_work_card.dart';
import 'package:esas/features/notification/presentation/routes/notification_routes.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:esas/features/profile/presentation/routes/profile_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Beranda sebagai pusat komando harian, bukan sebagai daftar pintasan.
///
/// ## Tiga tingkat, dan satu aturan yang mengikat semuanya
///
/// 1. **Mendominasi — hari ini.** [TodayWorkCard] dengan rim brand dan satu
///    kilau; tepat di bawahnya, hanya berjarak 12, [TodayTimeline] sebagai
///    rinciannya. Keduanya terbaca sebagai satu blok karena rapat, sementara
///    semua tetangganya jauh. Blok ini tidak punya `AppSectionHeader` sama
///    sekali: hal terpenting di sebuah dasbor tidak diperkenalkan oleh
///    micro-label yang sama dengan semua yang lain.
/// 2. **Menopang — akses cepat dan sisa cuti**, di atas kanvas yang sama,
///    dipisahkan jarak saja.
/// 3. **Mundur — kabar dan angka bulanan**, didahului jarak terbesar di
///    halaman (32) karena ini pergantian topik, bukan pergantian fakta.
///
/// Aturannya: **sebuah hitungan adalah fakta, dan fakta digambar redup; warna
/// disediakan untuk keadaan yang menuntut tindakan, dan satu-satunya tempat
/// keadaan dinyatakan adalah panel protagonis.**
///
/// ## Panel protagonis adalah STRUKTUR, bukan sebuah cabang
///
/// Ini pelajaran termahal dari layar ini, dan ia ditemukan di simulator dan
/// bukan oleh satu pun dari 3800 tes yang lulus saat itu.
///
/// Sebuah gelombang sebelumnya menukar seluruh [TodayWorkCard] dengan satu
/// pemberitahuan sebaris begitu absensi gagal dimuat. Secara teknis benar:
/// kalimatnya tepat, nadanya tepat, tombolnya tepat. Secara produk ia
/// menghancurkan halaman — pada akun yang absensinya dijawab 403, Beranda
/// menjadi kepala halaman, satu kalimat abu-abu, lalu langsung akses cepat.
/// Dasbor kehilangan jangkarnya persis pada saat sesuatu sedang salah, dan
/// akses cepat naik menjadi isi utama layar.
///
/// Jadi tidak ada cabang di sini yang menghapus panel itu. Yang berubah hanya
/// ISINYA: pada hari kerja ia menggambar shift, angka besar, rel jadwal, dua
/// fakta jam dan sebuah tombol; pada hari libur, akun tanpa izin absensi, atau
/// jaringan yang putus, ia menggambar tanggal, satu judul, satu kalimat, dan
/// paling banyak satu tautan. Anatominya sama, kekayaannya tidak.
///
/// ## Yang hilang, dan sengaja
///
/// Bagian "Perlu perhatian" sudah tidak ada. Begitu panel protagonis
/// menyatakan keadaan absensi dengan sebuah lencana, sebuah angka besar dan
/// sebuah tombol, baris di bawahnya yang berbunyi "Absen masuk belum tercatat"
/// hanya mengulang kalimat yang sama dengan bobot yang membuat keduanya tampak
/// setara. Hitungan pengumumannya tidak hilang: ia menjadi subjudul bagian
/// "Pengumuman", tempat ia memang berbicara tentang sesuatu.
///
/// Pita permukaan yang sempat menampung akses cepat juga sudah tidak ada.
/// Bedanya dengan kanvas hanya 1,02:1, jadi yang benar-benar terlihat darinya
/// cuma dua garis rambut selebar layar — dan dua garis itu membuat halaman
/// terbaca seperti halaman pengaturan yang dikelompokkan. Pengelompokan
/// sekarang dibawa jarak.
///
/// ## Yang tidak berubah, dan sengaja
///
/// Setiap tujuan tetap dicapai dengan `Get.offAllNamed` seperti sebelumnya —
/// itu pola navigasi bertab aplikasi ini, dan mengubahnya akan mengubah
/// tumpukan kembali di seluruh aplikasi, bukan hanya di sini.
bool _isTestEnvironment() {
  if (Get.testMode) return true;
  final String binding = WidgetsBinding.instance.runtimeType.toString();
  return binding.contains('Test') || binding.contains('Fake');
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with SingleTickerProviderStateMixin {
  late final HomeController controller;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<HomeController>();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    if (_isTestEnvironment()) {
      _entranceController.value = 1.0;
    } else {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await controller.refreshDashboard(force: true);
    if (!_isTestEnvironment() && mounted) {
      _entranceController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLayoutMetrics layout = AppLayout.of(context);
    final theme = Theme.of(context);
    final palette = theme.palette;
    final isDark = theme.brightness == Brightness.dark;

    return Title(
      title: 'Beranda – Absensas',
      color: Colors.black,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          confirmExitApp(context);
        },
        child: Scaffold(
          backgroundColor: isDark
              ? theme.scaffoldBackgroundColor
              : const Color(0xFFF8FAFC),
          appBar: _buildDefaultAppBar(context, theme, palette),
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: const Color(0xFF10B981),
              backgroundColor: Colors.white,
              onRefresh: _handleRefresh,
              child: ListView(
                controller: controller.scrollController,
                // Margin horizontal halaman dipasok per bagian lewat [AppPageInset].
                padding: const EdgeInsets.only(
                  top: 0,
                  bottom: AppSpacing.bottomSafe,
                ),
                children: <Widget>[AppContentClamp(child: _page(layout))],
              ),
            ),
          ),
          bottomNavigationBar: const CustomBottomNavBar(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildDefaultAppBar(
    BuildContext context,
    ThemeData theme,
    AppPalette palette,
  ) {
    return AppBar(
      toolbarHeight: 46,
      // Tanpa `elevation:` — `no_gradient_test` melarang kata itu di luar
      // `app_theme.dart`, dan `appBarTheme` sudah memberi 0.
      scrolledUnderElevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      titleSpacing: AppSpacing.page,
      shape: Border(
        bottom: BorderSide(color: palette.borderSubtle, width: 1.0),
      ),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.borderSubtle, width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo-square.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Obx(() {
              final String? company = controller.companyName.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    (company ?? 'ABSENSAS HRMS').toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF059669),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.6,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Beranda',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.2,
                      color: theme.colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
      actions: <Widget>[
        Center(
          child: Obx(
            () => HomeNotificationBell(
              count: controller.unreadNotifications.value,
              onTap: () => Get.toNamed(NotificationRoutes.notification),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Center(
          child: Obx(
            () => HomeAvatarButton(
              formattedName: controller.userName.value,
              avatarUrl: (controller.userAvatarUrl.value.isNotEmpty)
                  ? assetUrl(controller.userAvatarUrl.value)
                  : assetUrl(HomeHeader.defaultAvatarPath),
              size: 34,
              borderColor: palette.borderSubtle,
              onTap: () {
                if (Get.isRegistered<BottomNavController>()) {
                  Get.find<BottomNavController>().changeIndex(4);
                } else {
                  Get.toNamed(ProfileRoutes.profile);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.page),
      ],
    );
  }

  /// Susunan halaman untuk kelas ukuran yang sedang berlaku.
  ///
  /// Hanya ada satu percabangan tata letak di seluruh layar ini, dan ada di
  /// sini: satu kolom, atau dua kolom di dalam gulir yang sama. Bagian-bagiannya
  /// identik di kedua cabang — yang berubah cuma siapa yang memasang margin
  /// halaman, dan itulah sebabnya bagian-bagian di bawah dikumpulkan sebagai
  /// [_Beat] alih-alih sebagai `Widget` biasa.
  Widget _page(AppLayoutMetrics layout) {
    final List<_Beat> today = _todayBeats(layout);
    final List<_Beat> support = _supportBeats(layout);
    final List<_Beat> allBeats = <_Beat>[...today, ...support];
    final int totalBeats = allBeats.length + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StaggeredBeat(
          index: 0,
          total: totalBeats,
          animation: _entranceController,
          child: AppPageInset(child: _header()),
        ),
        // Sapaan dan protagonis adalah satu tarikan napas.
        const SizedBox(height: AppSpacing.xs),
        if (layout.twoColumn)
          AppPageInset(
            child: AppTwoColumn(
              primary: <Widget>[
                for (int i = 0; i < today.length; i++)
                  today[i].isGap
                      ? today[i].child
                      : _StaggeredBeat(
                          index: i + 1,
                          total: totalBeats,
                          animation: _entranceController,
                          child: today[i].child,
                        ),
              ],
              secondary: <Widget>[
                for (int i = 0; i < support.length; i++)
                  support[i].isGap
                      ? support[i].child
                      : _StaggeredBeat(
                          index: today.length + i + 1,
                          total: totalBeats,
                          animation: _entranceController,
                          child: support[i].child,
                        ),
              ],
            ),
          )
        else ...<Widget>[
          for (int i = 0; i < allBeats.length; i++)
            allBeats[i].isGap
                ? allBeats[i].child
                : _StaggeredBeat(
                    index: i + 1,
                    total: totalBeats,
                    animation: _entranceController,
                    child: AppPageInset(
                      bleed: allBeats[i].bleed,
                      child: allBeats[i].child,
                    ),
                  ),
        ],
      ],
    );
  }

  Widget _header() {
    return Obx(
      () => HomeHeader(
        userName: controller.userName.value,
        // Bentuk ringkas, supaya muat sebaris dengan pil sinkron. Bentuk
        // panjangnya tetap dipakai kartu hari ini.
        date: controller.currentDateShort.value.isEmpty
            ? null
            : controller.currentDateShort.value,
        // Semuanya dari sesi dan controller; `null` berarti barisnya tidak
        // digambar. Lonceng dan avatar ada di AppBar di atas, bukan di sini.
        position: controller.userPosition.value,
        department: controller.userDepartment.value,
        syncStatus: controller.syncStatus,
        syncedAt: controller.lastSyncedAt.value,
        showRefreshHint: !_isTestEnvironment(),
      ),
    );
  }

  // ── Tingkat 1: hari ini ───────────────────────────────────────────────────

  /// Panel protagonis dan rinciannya. Tidak ada judul bagian di tingkat ini.
  List<_Beat> _todayBeats(AppLayoutMetrics layout) {
    return <_Beat>[
      _Beat(
        Obx(() {
          final HomeTodayState state = controller.todayState;

          if (state == HomeTodayState.loading) {
            return const HomeHeroSkeleton();
          }

          // TIDAK ADA cabang yang mengganti kartu ini dengan sesuatu yang
          // lebih kecil. Versi sebelumnya menukarnya dengan satu
          // `AppInlineNotice` begitu absensi gagal dimuat, dan hasilnya adalah
          // Beranda yang kehilangan jangkarnya justru ketika sesuatu sedang
          // salah: setelah kepala halaman langsung akses cepat, tanpa satu pun
          // konteks tentang hari ini. Panel protagonis adalah STRUKTUR
          // permanen halaman ini; yang berubah hanya isinya.
          return TodayWorkCard(
            state: state,
            shiftName: controller.shiftName.value,
            scheduleIn: controller.scheduleIn.value,
            scheduleOut: controller.scheduleOut.value,
            timeIn: controller.timeIn.value,
            timeOut: controller.timeOut.value,
            lateMinutes: controller.lateMinutes,
            nextPunch: controller.nextPunch,
            canClock: controller.canClock,
            dayContext: controller.dayContext.value,
            error: controller.attendanceError.value,
            date: controller.currentDate.value.isEmpty
                ? null
                : controller.currentDate.value,
            onClock: () => Get.offAllNamed(AttendanceRoutes.attendance),
            onHistory: () => Get.offAllNamed(
              AttendanceRoutes.list,
              arguments: const {'back': HomeRoutes.home},
            ),
            onRetry: () => controller.refreshDashboard(force: true),
            onSignIn: _signInAgain,
          );
        }),
      ),

      // Rincian jadwal menempel pada protagonisnya — 12, dan tanpa judul
      // bagian. Ia menjawab "apakah saya sesuai jadwal", yang merupakan
      // kelanjutan dari angka di atasnya, bukan topik baru. Jaraknya ikut
      // hilang bersama isinya, karena sebuah jarak yang menggantung adalah
      // bagian kosong yang tetap dibayar.
      _Beat(const SizedBox.shrink()),

      // Pada dua kolom, kolom kiri berhenti di sini dan jaraknya menjadi
      // urusan barisnya; pada satu kolom, inilah jarak yang memisahkan tingkat
      // 1 dari tingkat 2.
      _Beat.gap(layout.twoColumn ? 0 : AppSpacing.sm),
    ];
  }

  // ── Tingkat 2 dan 3: penopang, lalu kabar ─────────────────────────────────

  List<_Beat> _supportBeats(AppLayoutMetrics layout) {
    return <_Beat>[
      _Beat(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AppSectionHeader(
              title: 'Akses cepat',
              subtitle: 'Pintasan tugas & pelaporan harian',
              dense: true,
              naturalCase: true,
            ),
            Obx(() {
              if (controller.todayState == HomeTodayState.loading) {
                return const HomeQuickActionsSkeleton();
              }

              // Satu-satunya bagian kontekstual di sini, dan ia bersandar pada
              // data yang benar-benar ada: arah ketukan berikutnya menurut
              // server. Sisanya tidak diurutkan ulang berdasarkan tebakan —
              // sebuah petak yang berpindah tempat antar pembukaan lebih lambat
              // dipakai daripada petak yang selalu ada di tempat yang sama.
              final bool leaving =
                  controller.nextPunch == AttendancePunch.clockOut;

              return HomeQuickActions(
                actions: <HomeQuickAction>[
                  // Petaknya tidak punya rupa "ditekankan" lagi, dan bukan
                  // hanya tidak memakainya: parameternya sudah dihapus dari
                  // `HomeQuickAction`. Sebuah penekanan yang masih bisa
                  // dinyalakan adalah pintu yang akan dibuka lagi dalam dua
                  // gelombang, dan tangkapan layar sudah membuktikan ke mana
                  // pintu itu bermuara.
                  HomeQuickAction(
                    icon: leaving
                        ? Icons.logout_rounded
                        : Icons.qr_code_scanner_rounded,
                    label: leaving ? 'Absen pulang' : 'Absen',
                    subtitle: leaving ? 'Pulang' : 'Presensi',
                    // Sorotan hanya ketika server memang mengharapkan sebuah
                    // ketukan. Petak bersorot yang menuju pintu terkunci adalah
                    // janji yang tidak bisa ditepati.
                    accent: controller.canPunchNow,
                    onTap: () => Get.offAllNamed(AttendanceRoutes.attendance),
                  ),
                  HomeQuickAction(
                    icon: Icons.post_add_rounded,
                    label: 'Ajukan izin',
                    subtitle: 'Formulir',
                    onTap: () => Get.offAllNamed(PermitRoutes.permit),
                  ),
                  HomeQuickAction(
                    icon: Icons.fact_check_outlined,
                    label: 'Pengajuan',
                    subtitle: 'Formulir',
                    onTap: () => Get.offAllNamed(PermitRoutes.list),
                  ),
                  HomeQuickAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Riwayat',
                    subtitle: 'Log Bulan',
                    onTap: () => Get.offAllNamed(
                      AttendanceRoutes.list,
                      arguments: const {'back': HomeRoutes.home},
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        // TIDAK menerobos margin. Bagian ini pernah dibungkus sebuah pita
        // `surfaceSubtle` selebar layar yang memasok paddingnya sendiri, dan
        // ketika pita itu dibubarkan, izin menerobosnya sempat tertinggal di
        // sini tanpa ada lagi yang memasok margin — sehingga "AKSES CEPAT",
        // "SISA CUTI", dan label petak pertama benar-benar digambar pada x=0,
        // menempel di kaca.
        //
        // Ini persis bahaya yang membuat daftar di bawah bertipe [_Beat]:
        // probe overflow menangkap LUAPAN, bukan margin yang hilang, jadi
        // sebuah bagian yang menempel di kaca tetap lulus setiap tes yang ada.
        // Yang menangkapnya cuma mata, atau sebuah pengukuran posisi x.
      ),
      _Beat.gap(AppSpacing.lg),
      // Layanan Perusahaan Enterprise (HRMS Ekstensi, GAMS, ITMS, Kotak Masuk Approval)
      _Beat(
        Obx(() {
          final activeModules = controller.activeModules.toList();
          final isApprover = controller.isApprover.value;
          // Shown whenever there is anything to show (HOME-06). It was hidden unless
          // a sibling panel was licensed or the person approved something — so
          // an HRMS-only employee never reached the schedule, overtime, loans
          // or the assistant, which have no other way in.

          final services = ModuleRegistry.getAvailableServices(
            activeModules: activeModules,
            isManager: isApprover,
          );

          final enterpriseServices = services
              .where(
                (s) =>
                    s.id != 'hrms_attendance' &&
                    s.id != 'hrms_permit_create' &&
                    s.id != 'hrms_permit_list' &&
                    s.id != 'hrms_attendance_history',
              )
              .toList();

          if (enterpriseServices.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppSectionHeader(
                title: 'Layanan Perusahaan',
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                dense: true,
                naturalCase: true,
                trailing: InkWell(
                  onTap: () =>
                      _showAllEnterpriseServices(context, enterpriseServices),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat semua',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              EnterpriseServicesGrid(
                services: enterpriseServices,
                onTapService: (service) => Get.toNamed(service.route),
              ),
            ],
          );
        }),
      ),

      _Beat.gap(AppSpacing.sm),

      _Beat(
        Obx(() {
          // Gagal memuat bukan nol. Sebuah panel yang gagal tidak berhak
          // menyatakan bahwa tidak ada pengumuman.
          final int? count = controller.announcementError.value != null
              ? null
              : controller.announcements.length;

          return AppSectionHeader(
            title: 'Pengumuman',
            naturalCase: true,
            dense: true,
            // Angkanya menjadi KALIMAT, bukan angka yatim di samping judul.
            // Sebagai "3" tersendiri ia tidak mengatakan tiga apa, dan mata
            // membacanya sebagai lencana keadaan — padahal ia cuma hitungan.
            subtitle: count == null || count == 0
                ? null
                : '$count informasi terbaru',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextButton(
                  // Pushed, so back returns here (HOME-02).
                  onPressed: () => Get.toNamed(HomeRoutes.announcement),
                  // `trailing` memintas konstruksi tombol bawaan
                  // `AppSectionHeader`, jadi target 48dp-nya ditulis ulang di
                  // sini alih-alih diwarisi.
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('Semua'),
                      SizedBox(width: AppSpacing.xxs),
                      Icon(Icons.chevron_right_rounded, size: AppIconSizes.md),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),

      _Beat(
        AnnouncementCarousel(controller: controller),
        bleed: true,
      ),

      // Tingkat 3, bagian pertama: apa yang terjadi dengan hal yang SAYA kirim.
      //
      // Ia berada di atas ringkasan dan saldo karena urutan kepentingannya
      // memang begitu: sebuah pengajuan yang baru disetujui menuntut perhatian
      // hari ini, sementara rekap bulanan dan sisa cuti adalah angka yang boleh
      // dibaca kapan saja.
      _Beat(
        Obx(() {
          final HomeRecentActivity activity = HomeRecentActivity(
            permits: controller.recentPermits.toList(),
            loading: !controller.hasLoaded.value && controller.isLoading.value,
            error: controller.activityError.value != null,
          );

          if (!activity.hasContent) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: AppSpacing.xxl),
              AppSectionHeader(
                title: 'Aktivitas terbaru',
                dense: true,
                naturalCase: true,
                actionLabel: activity.isNavigable ? 'Semua' : null,
                onAction: activity.isNavigable
                    ? () => Get.offAllNamed(PermitRoutes.list)
                    : null,
              ),
              activity,
            ],
          );
        }),
      ),

      _Beat(
        Obx(() {
          final HomeMonthlySnapshot snapshot = HomeMonthlySnapshot(
            summary: controller.monthSummary.value,
            loading: !controller.hasLoaded.value && controller.isLoading.value,
            onOpen: () => Get.offAllNamed(
              AttendanceRoutes.list,
              arguments: const {'back': HomeRoutes.home},
            ),
          );

          if (!snapshot.hasContent) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: AppSpacing.xxl),
              AppSectionHeader(
                title: 'Ringkasan bulan ini',
                dense: true,
                naturalCase: true,
                actionLabel: 'Riwayat',
                onAction: () => Get.offAllNamed(
                  AttendanceRoutes.list,
                  arguments: const {'back': HomeRoutes.home},
                ),
              ),
              snapshot,
            ],
          );
        }),
      ),

      // Tingkat 3, bagian kedua: saldo yang bisa dipakai orangnya.
      //
      // Bagian ini dulu duduk DI ATAS pengumuman, berdempetan dengan akses
      // cepat. Tempatnya salah dua kali: ia bukan aksi, dan ia bukan kabar
      // perusahaan — ia konteks pribadi, yang urutannya datang SESUDAH
      // keduanya. Memindahkannya ke sini juga yang menyelesaikan separuh bawah
      // Beranda yang berhenti mendadak setelah korsel: zona itu sebelumnya
      // hanya berisi satu bagian, dan bagian itu menyembunyikan dirinya sendiri
      // begitu datanya kosong.
      _Beat(
        Obx(() {
          final HomeLeaveBalance leave = HomeLeaveBalance(
            balances: controller.leaveBalances.toList(),
            loading: !controller.hasLoaded.value && controller.isLoading.value,
            error: controller.leaveError.value != null,
            onOpen: () => Get.offAllNamed(PermitRoutes.permit),
            onRequests: () => Get.offAllNamed(PermitRoutes.list),
          );

          if (!leave.hasContent) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 24 antar bagian di zona ini, bukan 32: dua bagian konteks
              // pribadi terbaca sebagai satu kelompok, dan 32 disimpan untuk
              // pergantian topik yang sesungguhnya di atas.
              const SizedBox(height: AppSpacing.xxl),
              AppSectionHeader(
                title: 'Sisa cuti',
                dense: true,
                naturalCase: true,
                // Chevron hanya kalau ada yang benar-benar bisa dibuka.
                actionLabel: leave.isNavigable ? 'Ajukan' : null,
                onAction: leave.isNavigable
                    ? () => Get.offAllNamed(PermitRoutes.permit)
                    : null,
              ),
              leave,
            ],
          );
        }),
      ),
    ];
  }

  void _showAllEnterpriseServices(
    BuildContext context,
    List<EnterpriseServiceItem> services,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final palette = theme.palette;
        final bool isDark = theme.brightness == Brightness.dark;

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Header Sheet
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xs,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  'Layanan Perusahaan',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    letterSpacing: -0.3,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF064E3B)
                                        : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFA7F3D0),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    '${services.length}',
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFF059669),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Katalog layanan & modul operasional',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded, size: 22),
                        color: palette.textMuted,
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Divider(height: 1, color: palette.borderSubtle),
                // Daftar Layanan
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.md,
                      AppSpacing.page,
                      AppSpacing.lg,
                    ),
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      final service = services[index];
                      final visual = EnterpriseServiceVisual.resolve(
                        service,
                        isDark: isDark,
                        primaryColor: theme.colorScheme.primary,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              Get.toNamed(service.route);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? visual.cardBorder.withValues(alpha: 0.35)
                                      : visual.cardBorder.withValues(alpha: 0.5),
                                  width: 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: visual.iconBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        visual.icon,
                                        size: 20,
                                        color: visual.iconFg,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Flexible(
                                                child: Text(
                                                  service.title,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13.5,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: visual.tagBg,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  visual.tag,
                                                  style: TextStyle(
                                                    color: visual.tagFg,
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            service.description,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: palette.textMuted,
                                                  fontSize: 11.5,
                                                  height: 1.3,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: AppIconSizes.md,
                                      color: palette.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Akhiri sesi ini dan bawa orangnya ke layar masuk.
  ///
  /// Sesi yang sudah tidak berlaku tidak bisa diperbaiki oleh permintaan kedua,
  /// jadi tombolnya tidak menawarkan permintaan kedua. Kredensial lokal dibuang
  /// lebih dulu supaya splash tidak memulihkan sesi yang baru saja ditolak
  /// server; `AuthRepository` dijaga [GetInstance.isRegistered] karena Beranda
  /// bisa dibangun di dalam harness uji yang tidak mendaftarkannya — pola yang
  /// sama sudah dipakai `InitialBinding` untuk alasan yang sama.
  Future<void> _signInAgain() async {
    if (Get.isRegistered<AuthRepository>()) {
      await Get.find<AuthRepository>().logout();
    }

    Get.offAllNamed(AuthRoutes.login);
  }
}

/// Satu bagian halaman, beserta jawabannya atas satu pertanyaan: bolehkah ia
/// menyentuh tepi kaca.
///
/// Ini ada karena memindahkan margin dari daftar ke tiap bagian menyentuh
/// setiap anak sekaligus, dan probe overflow TIDAK akan menangkap kesalahannya:
/// ia menangkap luapan, bukan padding yang hilang, jadi satu bagian yang lupa
/// dibungkus akan menempel di kaca dan tetap lulus semua tes. Dengan daftar
/// bertipe `List<_Beat>`, yang menegakkannya adalah kompilator dan bukan
/// pembaca diff.
class _Beat {
  const _Beat(this.child, {this.bleed = false}) : isGap = false;

  _Beat.gap(double height)
    : child = SizedBox(height: height),
      bleed = false,
      isGap = true;

  final Widget child;

  /// Hanya berlaku pada kelas satu kolom; di kelas dua kolom margin dipasang
  /// sekali untuk seluruh baris dan tepi bagian bukan lagi tepi layar.
  final bool bleed;

  /// Penanda apakah ketukan ini merupakan jarak pemisah kosong.
  final bool isGap;
}

/// Pembungkus animasi masuk bertahap (staggered cascade) untuk setiap ketukan
/// halaman Beranda.
///
/// Setiap bagian meluncur naik secara halus (14px -> 0px) dan memudar masuk
/// (0.0 -> 1.0) dengan interval yang terkoordinasi.
///
/// Dalam lingkungan uji ([Get.testMode]), pembungkus ini langsung mengembalikan
/// [child] secara sinkron tanpa penundaan atau transformasi, menjamin seluruh
/// finder widget dan tes responsifitas berjalan instan tanpa timeout.
class _StaggeredBeat extends StatelessWidget {
  const _StaggeredBeat({
    required this.index,
    required this.total,
    required this.animation,
    required this.child,
  });

  final int index;
  final int total;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_isTestEnvironment()) return child;

    final double start = (index / (total + 3)).clamp(0.0, 0.7);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final CurvedAnimation curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: AppMotion.standard),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (BuildContext context, Widget? childWidget) {
        final double progress = curved.value;
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 14 * (1.0 - progress)),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}
