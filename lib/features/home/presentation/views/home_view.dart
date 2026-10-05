import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/components/custom_bottom_navbar.dart';
import 'package:esas/core/ui/dialogs/app_dialogs.dart';
import 'package:esas/core/ui/layout/app_breakpoints.dart';
import 'package:esas/core/ui/layout/app_responsive.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/features/home/presentation/widgets/announcement_carousel.dart';
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
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLayoutMetrics layout = AppLayout.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        confirmExitApp(context);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => controller.refreshDashboard(force: true),
            child: ListView(
              // Margin horizontal halaman TIDAK ada di sini lagi. Selama ia
              // tinggal di `padding` daftar, setiap anak dijepit ke lebar yang
              // sudah dikurangi margin dan tidak ada satu pun bagian yang bisa
              // menyentuh tepi kaca. Sekarang ia dipasok per bagian lewat
              // [AppPageInset], dan satu bagian boleh menolaknya.
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.bottomSafe,
              ),
              children: <Widget>[AppContentClamp(child: _page(layout))],
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNavBar(),
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPageInset(child: _header()),
        // 16, bukan 24. Sapaan dan protagonis adalah satu tarikan napas.
        const SizedBox(height: AppSpacing.lg),
        if (layout.twoColumn)
          AppPageInset(
            child: AppTwoColumn(
              primary: <Widget>[for (final _Beat beat in today) beat.child],
              secondary: <Widget>[for (final _Beat beat in support) beat.child],
            ),
          )
        else ...<Widget>[
          for (final _Beat beat in <_Beat>[...today, ...support])
            AppPageInset(bleed: beat.bleed, child: beat.child),
        ],
      ],
    );
  }

  Widget _header() {
    return Obx(
      () => HomeHeader(
        userName: controller.userName.value,
        userAvatarUrl: controller.userAvatarUrl.value,
        date: controller.currentDate.value.isEmpty
            ? null
            : controller.currentDate.value,
        // Dari SESI, bukan dari jaringan: Beranda tidak memanggil endpoint
        // notifikasi, dan tidak akan — satu permintaan HTTP untuk sebuah titik
        // merah adalah harga yang salah di jaringan pabrik. `null` berarti
        // belum pernah diketahui, dan lencananya tidak digambar sama sekali.
        notificationCount: controller.unreadNotifications.value,
        onNotifications: () => Get.offAllNamed(NotificationRoutes.notification),
        onAvatarTap: () => Get.offAllNamed(ProfileRoutes.profile),
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
            onHistory: () => Get.offAllNamed(AttendanceRoutes.list),
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
      _Beat(
        Obx(() {
          final TodayTimeline timeline = TodayTimeline(
            scheduleIn: controller.scheduleIn.value,
            scheduleOut: controller.scheduleOut.value,
            timeIn: controller.timeIn.value,
            timeOut: controller.timeOut.value,
            statusIn: controller.statusIn.value,
            statusOut: controller.statusOut.value,
          );

          if (!timeline.hasContent) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: timeline,
          );
        }),
      ),

      // Pada dua kolom, kolom kiri berhenti di sini dan jaraknya menjadi
      // urusan barisnya; pada satu kolom, inilah jarak yang memisahkan tingkat
      // 1 dari tingkat 2.
      _Beat.gap(layout.twoColumn ? 0 : AppSpacing.xxl),
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
                    // Sorotan hanya ketika server memang mengharapkan sebuah
                    // ketukan. Petak bersorot yang menuju pintu terkunci adalah
                    // janji yang tidak bisa ditepati.
                    accent: controller.canPunchNow,
                    onTap: () => Get.offAllNamed(AttendanceRoutes.attendance),
                  ),
                  HomeQuickAction(
                    icon: Icons.post_add_rounded,
                    label: 'Ajukan izin',
                    onTap: () => Get.offAllNamed(PermitRoutes.permit),
                  ),
                  HomeQuickAction(
                    icon: Icons.fact_check_outlined,
                    label: 'Pengajuan',
                    onTap: () => Get.offAllNamed(PermitRoutes.list),
                  ),
                  HomeQuickAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Riwayat',
                    onTap: () => Get.offAllNamed(AttendanceRoutes.list),
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

      // 32: jarak terbesar di halaman. Di sinilah topiknya berganti, dari
      // "hari kerja saya" menjadi "kabar dari perusahaan".
      _Beat.gap(AppSpacing.xxxl),

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
                  onPressed: () => Get.offAllNamed(HomeRoutes.announcement),
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
        // Pada satu kolom relnya lari keluar tepi kanan: margin kiri dipasang
        // sendiri, margin kanan sengaja tidak ada, sehingga kartu berikutnya
        // terpotong oleh kaca alih-alih oleh margin. Itu isyarat "masih ada
        // lagi" yang paling jujur, dan ia gratis.
        layout.heroBleeds
            ? Padding(
                padding: EdgeInsets.only(left: layout.pagePadding),
                child: AnnouncementCarousel(controller: controller),
              )
            : AnnouncementCarousel(controller: controller),
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
            onOpen: () => Get.offAllNamed(AttendanceRoutes.list),
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
                onAction: () => Get.offAllNamed(AttendanceRoutes.list),
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
  const _Beat(this.child, {this.bleed = false});

  _Beat.gap(double height) : child = SizedBox(height: height), bleed = false;

  final Widget child;

  /// Hanya berlaku pada kelas satu kolom; di kelas dua kolom margin dipasang
  /// sekali untuk seluruh baris dan tepi bagian bukan lagi tepi layar.
  final bool bleed;
}
