import 'package:esas/core/config/env.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/theme/theme_controller.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_metric_tile.dart';
import 'package:esas/core/ui/components/app_progress.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/ui/components/custom_bottom_navbar.dart';
import 'package:esas/core/ui/dialogs/app_dialogs.dart';
import 'package:esas/features/profile/presentation/routes/profile_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/profile_controller.dart';

/// Satu butir menu profil.
class ProfileMenuItem {
  const ProfileMenuItem(this.icon, this.title, this.route, {this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Nama rute, atau `null` bila butir ini ditangani secara khusus.
  final String? route;
}

/// Sekelompok butir menu di bawah satu judul.
class ProfileMenuGroup {
  const ProfileMenuGroup(this.title, this.items);

  final String title;
  final List<ProfileMenuItem> items;
}

/// Halaman profil.
///
/// Sepuluh butir menu sebelumnya berbaris sebagai sepuluh kartu identik dengan
/// jarak 8px — daftar yang panjangnya sama tetapi tanpa struktur, sehingga
/// "Ubah Kata Sandi" duduk sederajat dengan "Info Keluarga" dan tepat di
/// sebelah "Keluar".
///
/// Sekarang menu dikelompokkan menjadi tiga panel dengan judul: data karyawan,
/// akun, dan sesi. Pengelompokan itu juga yang memisahkan dua tindakan berisiko
/// — melepas workspace dan keluar — dari delapan tautan navigasi biasa, jadi
/// tidak ada lagi yang menekannya karena meleset satu baris.
class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  static const List<ProfileMenuGroup> _groups = <ProfileMenuGroup>[
    ProfileMenuGroup('Data karyawan', [
      ProfileMenuItem(
        Icons.person_outline_rounded,
        'Info personal',
        ProfileRoutes.personal,
        subtitle: 'Identitas, kontak, dan alamat',
      ),
      ProfileMenuItem(
        Icons.work_outline_rounded,
        'Info pekerjaan',
        ProfileRoutes.worked,
        subtitle: 'Jabatan, divisi, dan penempatan',
      ),
      ProfileMenuItem(
        Icons.family_restroom_rounded,
        'Info keluarga',
        ProfileRoutes.family,
      ),
      ProfileMenuItem(
        Icons.school_outlined,
        'Info pendidikan',
        ProfileRoutes.education,
      ),
      ProfileMenuItem(
        Icons.history_edu_outlined,
        'Pengalaman kerja',
        ProfileRoutes.experience,
      ),
      ProfileMenuItem(
        Icons.account_balance_wallet_outlined,
        'Slip gaji',
        ProfileRoutes.payroll,
      ),
    ]),
    ProfileMenuGroup('Akun', [
      ProfileMenuItem(
        Icons.lock_outline_rounded,
        'Ubah kata sandi',
        ProfileRoutes.changePassword,
      ),
      ProfileMenuItem(
        Icons.bug_report_outlined,
        'Laporkan masalah',
        ProfileRoutes.bugReport,
        subtitle: 'Kirim laporan bug ke tim IT',
      ),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
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
            onRefresh: controller.loadSummary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xl,
                AppSpacing.page,
                AppSpacing.bottomSafe,
              ),
              children: [
                const AppPageTitle(title: 'Profil'),
                const SizedBox(height: AppSpacing.xl),

                const _IdentityCard(),
                const SizedBox(height: AppSpacing.xl),

                const AppSectionHeader(
                  title: 'Performa & Kehadiran',
                  subtitle: 'Ringkasan statistik kehadiran Anda',
                  dense: true,
                ),
                const _PerformanceCard(),
                const SizedBox(height: AppSpacing.md),
                const _AttendanceStats(),

                for (final group in _groups) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  AppSectionHeader(title: group.title, dense: true),
                  _MenuPanel(
                    children: [
                      for (final item in group.items)
                        _MenuRow(
                          item: item,
                          onTap: () => Get.toNamed(item.route!),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),
                const AppSectionHeader(
                  title: 'Tampilan',
                  subtitle: 'Mode terang atau gelap untuk perangkat ini',
                  dense: true,
                ),
                const _MenuPanel(children: [_ThemeRow()]),

                const SizedBox(height: AppSpacing.xxl),
                const AppSectionHeader(
                  title: 'Sesi',
                  subtitle: 'Kelola perangkat dan sesi login',
                  dense: true,
                ),
                _MenuPanel(
                  children: [
                    _MenuRow(
                      item: const ProfileMenuItem(
                        Icons.swap_horiz_rounded,
                        'Pindah workspace',
                        null,
                        subtitle: 'Lepas perangkat dari workspace saat ini',
                      ),
                      onTap: () => _confirmSwitchWorkspace(context),
                    ),
                    _MenuRow(
                      item: const ProfileMenuItem(
                        Icons.logout_rounded,
                        'Keluar',
                        null,
                        subtitle: 'Akhiri sesi di perangkat ini',
                      ),
                      destructive: true,
                      onTap: () => _confirmLogout(context),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),
                const _WorkspaceFooter(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNavBar(),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool confirmed = await showAppConfirmDialog(
      context,
      title: 'Keluar dari akun?',
      message:
          'Anda perlu memasukkan NIP dan kata sandi lagi untuk masuk kembali.',
      confirmLabel: 'Keluar',
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (confirmed) controller.logout();
  }

  /// Konfirmasi sebelum perangkat diserahkan ke perusahaan lain.
  ///
  /// Nama workspace disebutkan di dalam pertanyaannya: "apakah Anda yakin"
  /// tanpa menyebut apa yang akan hilang adalah pertanyaan yang tidak mungkin
  /// dijawab keliru, dan karena itu tidak berguna (ADR-0005 §3).
  Future<void> _confirmSwitchWorkspace(BuildContext context) async {
    final bool confirmed = await showAppConfirmDialog(
      context,
      title: 'Pindah workspace?',
      message:
          'Perangkat ini akan dilepas dari workspace "${controller.workspace}" '
          'dan Anda akan keluar dari akun.',
      confirmLabel: 'Lanjutkan',
      icon: Icons.swap_horiz_rounded,
    );
    if (confirmed) controller.switchWorkspace();
  }
}

/// Kartu identitas: foto, nama, jabatan, dan dua lencana.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final controller = Get.find<ProfileController>();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final String avatarUrl = controller.avatar.value;
            ImageProvider? image;
            if (controller.pickedImageFile.value != null) {
              image = FileImage(controller.pickedImageFile.value!);
            } else if (avatarUrl.isNotEmpty) {
              image = NetworkImage(
                avatarUrl.startsWith(Env.assetBaseUrl)
                    ? avatarUrl
                    : '${Env.assetBaseUrl}/$avatarUrl',
              );
            }

            return GestureDetector(
              onTap: controller.pickImageFromGallery,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: palette.brandSubtle,
                      borderRadius: AppRadii.xlAll,
                      border: Border.all(color: palette.borderSubtle),
                      image: image == null
                          ? null
                          : DecorationImage(image: image, fit: BoxFit.cover),
                    ),
                    alignment: Alignment.center,
                    child: image == null
                        ? Icon(
                            Icons.person_outline_rounded,
                            size: AppIconSizes.xxl,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  // Penanda bahwa foto bisa diganti. Sebelumnya berupa ikon
                  // kamera di atas lingkaran semi-transparan yang nyaris tak
                  // terlihat di atas foto yang terang.
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: AppRadii.smAll,
                        border: Border.all(color: palette.borderStrong),
                      ),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: AppIconSizes.xs,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => Text(
                    controller.name.value,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Obx(
                  () => Text(
                    controller.jobTitle.value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => Wrap(
                    spacing: AppSpacing.tight,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppBadge(
                        label: controller.status.value,
                        tone: AppBadgeTone.brand,
                        dense: true,
                      ),
                      AppBadge(
                        label:
                            'Bergabung ${DateFormat('MMM yyyy', 'id').format(controller.joined.value)}',
                        icon: Icons.event_outlined,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skor performa kehadiran, sebagai angka dan sebagai batang.
///
/// Sebelumnya angka ini tampil sebagai pil hijau pekat bertuliskan
/// "0.982 Performa kehadiran" — mencolok, tetapi tanpa acuan. Angka tanpa skala
/// tidak bisa dinilai: 0.982 itu bagus atau buruk? Dua hal menjawabnya di sini.
/// Angkanya sendiri ditulis sebagai persen bulat, satuan yang sudah dipakai
/// orang untuk menilai kehadiran, bukan sebagai pecahan yang perlu
/// diterjemahkan lebih dulu. Dan batang di bawahnya membawa ambang 90% yang
/// dipakai kartu ini untuk memberi nada — ambang itu selama ini menentukan
/// warna badge tanpa pernah disebutkan kepada orang yang dinilainya.
class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard();

  /// Ambang "Sangat baik". Nilainya sudah menentukan nada kartu ini sejak awal;
  /// yang baru hanyalah bahwa sekarang ia ikut ditulis.
  static const double _target = 0.9;

  /// Jarak ke ambang, dalam kalimat. Selisihnya yang menjawab pertanyaan
  /// "cukup atau belum", bukan angka persennya sendiri.
  static String _distance(int percent) {
    final int target = (_target * 100).round();
    final int gap = percent - target;

    if (gap == 0) return 'tepat di target';

    return gap > 0
        ? '$gap poin di atas target'
        : '${-gap} poin di bawah target';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final controller = Get.find<ProfileController>();

    return AppCard(
      child: Obx(() {
        if (controller.isLoadingInitial.value) {
          return const _PerformanceSkeleton();
        }

        final double value = controller.points.value;
        final double ratio = (value > 1 ? value / 100 : value).clamp(0.0, 1.0);
        final int percent = (ratio * 100).round();
        final AppTone tone = ratio >= _target
            ? palette.success
            : ratio >= 0.7
            ? palette.warning
            : palette.danger;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PERFORMA KEHADIRAN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$percent%',
                        style: AppTypography.dataLarge(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: AppBadge(
                    label: ratio >= _target
                        ? 'Sangat baik'
                        : ratio >= 0.7
                        ? 'Cukup'
                        : 'Perlu perhatian',
                    tone: ratio >= _target
                        ? AppBadgeTone.success
                        : ratio >= 0.7
                        ? AppBadgeTone.warning
                        : AppBadgeTone.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppLinearProgress(
              value: ratio,
              height: 8,
              accentColor: tone.foreground,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Satu kalimat, bukan dua kolom: pada skala teks 1.5 sepasang teks
            // di ujung baris yang sama saling menabrak, sementara satu kalimat
            // membungkus ke baris berikutnya dan tetap terbaca.
            Text(
              'Target ${(_target * 100).round()}% · '
              '${_distance(percent)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Bentuk kartu performa selama ringkasan masih di jalan.
///
/// Tanpa ini layar profil membuka dengan "0%" dan lencana merah "Perlu
/// perhatian" selama satu perjalanan jaringan — sebuah penilaian tentang
/// karyawan yang belum ada datanya, dan penilaian terburuk yang bisa
/// ditampilkan aplikasi ini.
class _PerformanceSkeleton extends StatelessWidget {
  const _PerformanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSkeleton(width: 140, height: 11),
              Spacer(),
              AppSkeleton(width: 72, height: 20),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(width: 96, height: 28),
          SizedBox(height: AppSpacing.lg),
          // Baris sendiri, karena kotak selebar induk di dalam kolom yang
          // rata kiri akan menyusut menjadi nol.
          Row(children: [Expanded(child: AppSkeleton(height: 8))]),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(width: 120, height: 11),
        ],
      ),
    );
  }
}

/// Dua angka kehadiran, masing-masing dengan penyebutnya.
///
/// Panel sebelumnya menampilkan tiga angka sederajat — terlambat, total, tepat
/// waktu — dan yang di tengah adalah penyebut dari dua yang lain. Sebuah "21"
/// tanpa "dari 22" tidak bisa dinilai, sementara "21 dari 22 absensi" tidak
/// perlu dijelaskan sama sekali; jadi totalnya turun menjadi keterangan dan
/// berhenti bersaing sebagai angka besar ketiga.
class _AttendanceStats extends StatelessWidget {
  const _AttendanceStats();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ProfileController>();

    return Obx(() {
      if (controller.isLoadingInitial.value) {
        return const _StatsSkeleton();
      }

      final int total = controller.attendance.value;
      final int onTime = controller.unlate.value;
      final int late = controller.late.value;
      final String denominator = total == 0
          ? 'belum ada absensi'
          : 'dari $total absensi';

      // Pembandingnya adalah penyebutnya, dan hanya itu. Sempat ada chip
      // persentase di sini, sampai terlihat bahwa bagian tepat waktu terhadap
      // total ADALAH angka performa di kartu di atasnya — dua tempat yang
      // menggambar satu besaran yang sama adalah dua tempat yang suatu hari
      // akan berselisih.
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AppMetricTile.count(
                label: 'Tepat waktu',
                count: onTime,
                caption: denominator,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppMetricTile.count(
                label: 'Terlambat',
                count: late,
                caption: denominator,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonPulse(
      child: Row(
        children: [
          Expanded(child: _StatSkeletonTile()),
          SizedBox(width: AppSpacing.md),
          Expanded(child: _StatSkeletonTile()),
        ],
      ),
    );
  }
}

class _StatSkeletonTile extends StatelessWidget {
  const _StatSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 48, height: 28),
          SizedBox(height: AppSpacing.xs),
          AppSkeleton(width: 72, height: 11),
          SizedBox(height: AppSpacing.xxs),
          AppSkeleton(width: 88, height: 11),
        ],
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).palette;

    // `Material` transparan, bukan sekadar pembungkus: setiap baris di bawah
    // adalah `InkWell`, dan sebuah `InkWell` tanpa leluhur `Material` melukis
    // ripple-nya di belakang isian kartu. Sepuluh baris menu — termasuk
    // "Keluar" — karena itu tidak pernah sekali pun memberi umpan balik sentuh.
    return AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: palette.borderSubtle),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.onTap,
    this.destructive = false,
  });

  final ProfileMenuItem item;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final Color foreground = destructive
        ? palette.danger.foreground
        : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: AppIconSizes.lg,
              color: destructive
                  ? palette.danger.foreground
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      item.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: AppIconSizes.lg,
              color: palette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pengalih mode terang/gelap.
///
/// Kembali ke sini setelah sempat hilang: tombolnya dulu duduk di kepala
/// beranda, dan ketika beranda dibangun ulang menjadi panel data, tombol itu
/// ikut terbawa keluar — sehingga aplikasi punya dua tema dan tidak punya satu
/// pun cara untuk berpindah di antaranya. Tempatnya memang di sini, sederajat
/// dengan pengaturan perangkat lain, bukan di sebelah nama orang.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final ThemeController controller = Get.find<ThemeController>();

    // `Obx`, bukan `GetBuilder`: `toggleTheme` tidak memanggil `update()`, jadi
    // sebuah `GetBuilder` hanya akan tergambar ulang karena `changeThemeMode`
    // kebetulan membangun ulang seluruh aplikasi. Yang benar-benar berubah
    // adalah `RxBool` di dalam controller, dan itulah yang didengarkan di sini.
    return Obx(() {
      final bool dark = controller.isDarkMode;

      return InkWell(
        onTap: controller.toggleTheme,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md + 2,
          ),
          child: Row(
            children: [
              Icon(
                dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: AppIconSizes.lg,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Mode gelap', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      dark ? 'Sedang aktif' : 'Sedang nonaktif',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Sakelarnya sendiri tidak memasang `onChanged` terpisah:
              // seluruh baris adalah targetnya, jadi tidak ada dua area
              // sentuh yang melakukan hal yang sama dengan ukuran berbeda.
              IgnorePointer(
                child: Switch(value: dark, onChanged: (_) {}),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Kaki halaman: workspace mana yang sedang dipakai perangkat ini.
///
/// Informasi ini sebelumnya hanya muncul di dalam dialog konfirmasi pindah
/// workspace — artinya baru terlihat setelah orang menekan tombol yang berisiko.
class _WorkspaceFooter extends StatelessWidget {
  const _WorkspaceFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final controller = Get.find<ProfileController>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.dns_outlined,
          size: AppIconSizes.xs,
          color: palette.textMuted,
        ),
        const SizedBox(width: AppSpacing.tight),
        Text(
          'Workspace ${controller.workspace}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: palette.textMuted,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
