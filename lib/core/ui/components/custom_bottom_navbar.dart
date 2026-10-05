import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../controllers/bottom_nav_controller.dart';

/// Satu tujuan pada bilah navigasi.
class _NavDestination {
  const _NavDestination(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Bilah navigasi utama.
///
/// Dibangun sendiri alih-alih memakai [BottomNavigationBar] karena tiga hal
/// yang tidak bisa diatur pada widget bawaan itu:
///
/// * Garis 1px di tepi atas, bukan bayangan. Bayangan `elevation: 8` bawaan
///   tampak sebagai kabut kotor di atas latar gelap.
/// * Ikon garis saat tidak aktif dan ikon padat saat aktif. Perbedaan bentuk
///   membuat tab aktif terbaca bahkan sebelum warnanya terdaftar oleh mata,
///   yang penting bagi pengguna dengan buta warna.
/// * Label yang tidak pernah berpindah posisi saat tab berganti.
class CustomBottomNavBar extends GetView<BottomNavController> {
  const CustomBottomNavBar({super.key, this.notificationCount});

  /// Jumlah notifikasi yang belum dibaca, digambar sebagai lencana kecil pada
  /// tujuan Notifikasi. Boleh `null` selama pemanggilnya belum punya angkanya.
  ///
  /// Tanpa ini tidak ada satu tempat pun di seluruh aplikasi yang mengatakan
  /// bahwa ada sesuatu yang menunggu, padahal hitungannya sudah dikirim server
  /// di setiap respons daftar notifikasi.
  final int? notificationCount;

  /// Indeks tujuan Notifikasi. Ditulis sekali di sini supaya slot lencananya
  /// tidak ikut salah kalau urutan tab berubah.
  static const int _notificationIndex = 3;

  static const List<_NavDestination> _destinations = <_NavDestination>[
    _NavDestination(
      Icons.grid_view_outlined,
      Icons.grid_view_rounded,
      'Beranda',
    ),
    _NavDestination(
      Icons.qr_code_scanner_rounded,
      Icons.qr_code_scanner_rounded,
      'Absensi',
    ),
    _NavDestination(
      Icons.assignment_outlined,
      Icons.assignment_rounded,
      'Pengajuan',
    ),
    _NavDestination(
      Icons.notifications_none_rounded,
      Icons.notifications_rounded,
      'Notifikasi',
    ),
    _NavDestination(
      Icons.person_outline_rounded,
      Icons.person_rounded,
      'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          // Riak navigasi butuh sebuah [Material] di antaranya dan `Container`
          // opaque di atas. Tanpa lapisan ini setiap `InkWell` di bawah melukis
          // riaknya di belakang bilah, dan tidak seorang pun pernah melihat
          // umpan balik ketukan pada navigasi utama aplikasi.
          child: Material(
            type: MaterialType.transparency,
            child: Obx(() {
              final int current = controller.currentIndex.value;
              return Row(
                children: List<Widget>.generate(_destinations.length, (index) {
                  return Expanded(
                    child: _NavItem(
                      destination: _destinations[index],
                      selected: index == current,
                      badgeCount: index == _notificationIndex
                          ? notificationCount
                          : null,
                      onTap: () => controller.changeIndex(index),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final Color color = selected
        ? theme.colorScheme.primary
        : palette.textMuted;

    final int count = badgeCount ?? 0;
    final bool showBadge = count > 0;

    final Widget icon = AnimatedContainer(
      duration: AppDurations.fast,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: selected ? palette.brandSubtle : Colors.transparent,
        borderRadius: AppRadii.pillAll,
      ),
      child: Icon(
        selected ? destination.activeIcon : destination.icon,
        size: AppIconSizes.xl,
        color: color,
      ),
    );

    return Semantics(
      selected: selected,
      button: true,
      // Angkanya ikut dibacakan: sebuah titik merah tidak mengatakan apa pun
      // kepada pembaca layar.
      label: showBadge
          ? '${destination.label}, $count belum dibaca'
          : destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!showBadge)
              icon
            else
              Stack(
                clipBehavior: Clip.none,
                children: [
                  icon,
                  Positioned(
                    top: -AppSpacing.xs,
                    right: -AppSpacing.xs,
                    child: _NavBadge(count: count),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                letterSpacing: 0,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lencana hitungan di atas ikon navigasi.
///
/// Sengaja tidak memakai `AppBadge`: lencana status dibangun untuk duduk di
/// dalam sebuah baris, sementara yang ini menempel di sudut ikon dan harus
/// tetap kecil. Nadanya tetap diambil dari palet, jadi isian, garis, dan
/// hurufnya berpindah bersama tema seperti lencana lain.
class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppTone tone = theme.palette.danger;

    return Container(
      constraints: const BoxConstraints(minWidth: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: tone.border),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        maxLines: 1,
        // Tanpa `fontSize` sendiri: 10px berada di bawah lantai 12px yang
        // dipatok aturan tampilan ini, dan sebuah penghitung yang tidak
        // terbaca tidak lebih baik daripada tidak ada penghitung.
        style: theme.textTheme.labelSmall?.copyWith(
          color: tone.foreground,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
