import 'package:esas/core/config/asset_url.dart';
import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:esas/core/utils/string_utils.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_avatar.dart';
import 'package:esas/core/ui/layout/app_breakpoints.dart';
import 'package:flutter/material.dart';

/// Kepala Beranda: siapa yang masuk, hari apa ini, dan apa yang menunggu.
///
/// Bukan sebuah `AppBar`. Sebuah app bar menuntut tingginya sendiri, garis
/// kakinya sendiri, dan seringkali sebuah bayangan — tiga hal yang membuat
/// bagian teratas layar terbaca sebagai krom aplikasi, padahal isinya adalah
/// data. Di sini ia adalah baris pertama halaman, menggulir bersama sisanya.
///
/// Tiga hal yang sudah tidak ada di sini dan sengaja tidak dikembalikan: logo
/// perusahaan sebagai watermark 10% (tekstur di balik teks yang tidak
/// menyampaikan apa pun kepada orang yang sudah tahu di mana ia bekerja),
/// tombol ganti tema (preferensi yang diubah sekali seumur pemakaian, menempati
/// sudut termahal di layar yang paling sering dibuka), dan strip tanggal
/// tersendiri di bawahnya — tanggalnya sekarang baris ketiga di kolom ini,
/// karena sebuah kartu berisi satu kalimat tanggal adalah kartu yang
/// membelanjakan 56px untuk sembilan kata.
///
/// Singkatan zona (WIB/WITA/WIT) ikut karena setiap jam di layar ini digambar
/// pada jam KANTOR, bukan jam ponsel, dan satu-satunya cara pengguna bisa tahu
/// itu adalah kalau layarnya mengatakannya.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.userName,
    required this.userAvatarUrl,
    this.date,
    this.notificationCount,
    this.onNotifications,
    this.onAvatarTap,
  });

  final String userName;
  final String? userAvatarUrl;

  /// Tanggal hari ini, sudah diformat pada jam workspace. Baris ini hilang
  /// seluruhnya bila belum ada — sebuah tanggal kosong lebih buruk daripada
  /// tidak ada tanggal.
  final String? date;

  /// Jumlah notifikasi belum dibaca.
  ///
  /// `null` berarti BELUM DIKETAHUI, dan lencananya tidak digambar sama sekali —
  /// sebuah nol yang dikarang akan berbohong setiap pagi.
  ///
  /// Angkanya datang dari sesi, tidak pernah dari permintaan milik layar ini:
  /// satu permintaan HTTP untuk sebuah titik merah adalah harga yang salah di
  /// jaringan pabrik. Sesi mengisinya dari dua sumber yang sudah dibayar —
  /// `unread_notification_count` pada payload sesi bila backend mengirimnya,
  /// dan `unread_count` yang memang dibawa setiap halaman daftar notifikasi.
  final int? notificationCount;

  final VoidCallback? onNotifications;
  final VoidCallback? onAvatarTap;

  static const String defaultAvatarPath = 'esas-assets/default.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final bool tight = AppLayout.of(context).compactHeader;

    // `toBeginningOfSentenceCase` adalah jawaban yang salah untuk sebuah NAMA:
    // ia menghasilkan "Alan gentina" — satu huruf kapital untuk dua kata yang
    // dua-duanya nama diri. Terlihat di tangkapan layar runtime, tidak terlihat
    // di satu pun tes.
    final String formattedName = personName(userName) ?? userName;

    final String avatarUrl =
        (userAvatarUrl != null && userAvatarUrl!.isNotEmpty)
        ? assetUrl(userAvatarUrl!)
        : assetUrl(defaultAvatarPath);

    final String zone = WorkspaceClock.current.abbreviation;
    final String? dateLine = date == null ? null : '$date · $zone';

    // Pada layar yang tingginya langka, sapaan dan tanggal berbagi satu baris.
    // Yang dikorbankan adalah baris, bukan informasi.
    final List<Widget> lines = <Widget>[
      if (!tight)
        Text(
          DateFormatter.greeting(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: palette.textMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      Text(
        formattedName,
        style: theme.textTheme.headlineSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      if (dateLine != null)
        Text(
          tight ? '${DateFormatter.greeting()} · $dateLine' : dateLine,
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
    ];

    return Row(
      children: <Widget>[
        AppAvatar(
          userName: formattedName,
          imageUrl: avatarUrl,
          size: tight ? 40 : 48,
          onTap: onAvatarTap,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < lines.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: AppSpacing.xxs),
                lines[i],
              ],
            ],
          ),
        ),
        if (onNotifications != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          _NotificationBell(count: notificationCount, onTap: onNotifications!),
        ],
      ],
    );
  }
}

/// Lonceng notifikasi, dengan penanda kecil bila ada yang belum dibaca.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});

  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final int unread = count ?? 0;
    final bool showBadge = unread > 0;

    return Semantics(
      button: true,
      // Sebuah titik merah tidak mengatakan apa pun kepada pembaca layar, jadi
      // angkanya ikut dibacakan ketika ia ada.
      label: showBadge ? 'Notifikasi, $unread belum dibaca' : 'Notifikasi',
      // Angka di dalam lencana TIDAK dibacakan lagi sebagai simpul tersendiri:
      // tanpa ini pembaca layar mengucapkan "Notifikasi, 3 belum dibaca" lalu
      // "3", dan yang kedua tidak menambah apa pun.
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pillAll,
          child: Container(
            // 48dp: lantai target sentuh, dijaga terpisah dari ukuran ikonnya.
            // Angkanya 48 dan bukan 44 karena lonceng ini digambar di baris
            // paling atas layar, tempat ibu jari paling sering meleset, dan
            // karena tidak ada satu pun tata letak di sini yang membayar
            // tingginya — barisnya sudah lebih tinggi daripada 48 di setiap
            // kelas ukuran, jadi empat piksel itu gratis.
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(
                  Icons.notifications_none_rounded,
                  size: AppIconSizes.xxl,
                  color: theme.colorScheme.onSurface,
                ),
                if (showBadge)
                  Positioned(
                    top: -AppSpacing.xxs,
                    right: -AppSpacing.xs,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.md,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: palette.danger.background,
                        borderRadius: AppRadii.pillAll,
                        border: Border.all(color: palette.danger.border),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.danger.foreground,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
