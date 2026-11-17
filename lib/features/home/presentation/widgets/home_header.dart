import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_avatar.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:esas/core/utils/string_utils.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/widgets/home_ui.dart';
import 'package:flutter/material.dart';

/// Kepala isi Beranda: seberapa segar layar ini, hari apa ini, dan siapa saya.
///
/// Bilah atasnya (logo, judul, lonceng, avatar) tinggal di `AppBar` milik
/// layar; yang digambar di sini hanya tiga baris di bawahnya:
///
/// 1. **Baris status** — pil sinkron di kiri, tanggal di kanan.
/// 2. **Sapaan** — "Selamat Pagi, Dimas", dengan nama depan.
/// 3. **Peran** — jabatan (hijau) dan departemen (redup).
///
/// ## Tidak ada kalimat atau warna yang ditulis mati
///
/// Setiap potong teks datang dari data, dan setiap potong yang datanya tidak
/// ada TIDAK DIGAMBAR — tidak ada pengganti yang dikarang:
///
/// * sapaan  ← jam workspace ([DateFormatter.greeting]) dan nama depan;
/// * peran   ← [position] dan [department] dari sesi;
/// * pil     ← [syncStatus] dan [syncedAt] milik controller;
/// * tanggal ← [date], sudah diformat pada jam workspace.
///
/// Versi sebelumnya menulis "Tersinkronisasi • Kantor Pusat (WFO)" dan
/// "Lead UI/UX Engineer • Tech Division" untuk setiap orang, dan menggambar
/// tanggal contoh bila tanggal aslinya belum ada. Tidak ada payload yang
/// membawa lokasi kerja atau modenya, jadi kalimat itu adalah klaim tentang
/// kantor seseorang yang tidak pernah diketahui aplikasi — dan ia tetap terbaca
/// "tersinkronisasi" bahkan ketika ponselnya sedang luring. Warnanya juga
/// heksadesimal tetap: teks navy `#0F172A` di atas kanvas gelap tidak terbaca
/// sama sekali. Sekarang semuanya dari [ThemeData] dan [AppPalette], dan
/// berpindah bersama tema.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.userName,
    this.date,
    this.position,
    this.department,
    this.syncStatus,
    this.syncedAt,
    this.showRefreshHint = true,
  });

  final String userName;

  /// Tanggal hari ini, sudah diformat pada jam workspace. Hilang seluruhnya
  /// bila belum ada — sebuah tanggal kosong (atau tanggal contoh) lebih buruk
  /// daripada tidak ada tanggal.
  final String? date;

  /// Jabatan dan departemen dari sesi. Masing-masing boleh `null`; bila
  /// keduanya `null` barisnya tidak digambar.
  final String? position;
  final String? department;

  /// Seberapa segar data di layar; `null` menghilangkan pilnya (dipakai
  /// pemanggil yang tidak punya controller). Lihat [HomeSyncStatus].
  final HomeSyncStatus? syncStatus;

  /// Kapan penyegaran terakhir yang berhasil selesai, pada jam workspace.
  final DateTime? syncedAt;

  /// Petunjuk tarik-untuk-menyegarkan di atas baris status.
  final bool showRefreshHint;

  static const String defaultAvatarPath = 'esas-assets/default.png';

  /// "selamat pagi" → "Selamat Pagi". Sapaan datang dari [DateFormatter] dalam
  /// kalimat biasa; judul sebesar ini dibaca lebih baik dengan huruf awal tiap
  /// kata.
  static String _titleCase(String text) => text
      .split(' ')
      .map(
        (String w) =>
            w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    // `toBeginningOfSentenceCase` adalah jawaban yang salah untuk sebuah NAMA:
    // ia menghasilkan "Alan gentina". `personName` hanya menyentuh nama yang
    // seluruhnya kapital atau seluruhnya kecil.
    final String formattedName = personName(userName) ?? userName;

    final bool hasStatusRow = syncStatus != null || date != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showRefreshHint)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Center(
              child: Text(
                '↓ Tarik ke bawah untuk memperbarui',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          ),

        // ── 1. Baris status ─────────────────────────────────────────────────
        if (hasStatusRow)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if (syncStatus != null)
                  Flexible(child: _syncPill(context, syncStatus!)),
                if (syncStatus != null && date != null)
                  const SizedBox(width: AppSpacing.sm),
                if (date != null)
                  Flexible(
                    child: Text(
                      date!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // ── 2. Sapaan ───────────────────────────────────────────────────────
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${_titleCase(DateFormatter.greeting())}, ',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              Text(
                formattedName,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              Text(
                ' 👋',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),

        // ── 3. Peran ────────────────────────────────────────────────────────
        if (_roleLine(theme, palette) case final Widget role) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          role,
        ],
      ],
    );
  }

  /// "Lead UI/UX Engineer • Tech Division": jabatan hijau, departemen redup.
  /// `null` bila keduanya tidak ada — baris kosong lebih buruk daripada tidak
  /// ada baris.
  Widget? _roleLine(ThemeData theme, AppPalette palette) {
    final bool hasPosition = position != null && position!.isNotEmpty;
    final bool hasDepartment = department != null && department!.isNotEmpty;

    if (!hasPosition && !hasDepartment) return null;

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          if (hasPosition)
            TextSpan(
              text: position,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (hasPosition && hasDepartment)
            TextSpan(
              text: ' • ',
              style: TextStyle(color: palette.textMuted),
            ),
          if (hasDepartment)
            TextSpan(
              text: department,
              style: TextStyle(color: palette.textMuted),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium,
    );
  }

  /// Pil sinkron. Warnanya mengikuti kenyataan: hijau hanya bila memang
  /// tersinkronisasi, kuning ketika luring, netral selagi memuat.
  Widget _syncPill(BuildContext context, HomeSyncStatus status) {
    final AppPalette palette = Theme.of(context).palette;
    final String? time = syncedAt == null ? null : _clock(syncedAt!);

    // Jam di sini adalah jam WORKSPACE, bukan jam ponsel, jadi singkatan
    // zonanya ikut — itu satu-satunya cara orang bisa tahu.
    final String zone = WorkspaceClock.current.abbreviation;

    final (String label, AppTone tone) = switch (status) {
      HomeSyncStatus.loading => ('Memuat data…', palette.neutral),
      HomeSyncStatus.refreshing => ('Memperbarui…', palette.neutral),
      HomeSyncStatus.offline => (
        time == null ? 'Luring' : 'Luring • data $time $zone',
        palette.warning,
      ),
      HomeSyncStatus.synced => (
        time == null ? 'Tersinkronisasi' : 'Tersinkronisasi • $time $zone',
        palette.success,
      ),
    };

    return HomePill(label: label, tone: tone, showDot: true, compact: true);
  }
}

/// Avatar pengguna dengan respon pegas taktil saat diketuk.
class HomeAvatarButton extends StatefulWidget {
  const HomeAvatarButton({
    super.key,
    required this.formattedName,
    required this.avatarUrl,
    required this.size,
    required this.borderColor,
    this.onTap,
  });

  final String formattedName;
  final String avatarUrl;
  final double size;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  State<HomeAvatarButton> createState() => _HomeAvatarButtonState();
}

class _HomeAvatarButtonState extends State<HomeAvatarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.93 : 1.0,
      duration: AppDurations.fast,
      curve: AppMotion.standard,
      child: Listener(
        onPointerDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onPointerUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onPointerCancel: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        child: Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.borderColor, width: 1.0),
          ),
          child: AppAvatar(
            userName: widget.formattedName,
            imageUrl: widget.avatarUrl,
            size: widget.size,
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}

/// Lonceng notifikasi, dengan lencana hitungan merah bila ada yang belum
/// dibaca.
class HomeNotificationBell extends StatefulWidget {
  const HomeNotificationBell({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int? count;
  final VoidCallback onTap;

  @override
  State<HomeNotificationBell> createState() => _HomeNotificationBellState();
}

class _HomeNotificationBellState extends State<HomeNotificationBell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    final int unread = widget.count ?? 0;
    final bool showBadge = unread > 0;

    return Semantics(
      button: true,
      // Sebuah titik tidak mengatakan apa pun kepada pembaca layar, jadi
      // angkanya ikut dibacakan ketika ia ada.
      label: showBadge ? 'Notifikasi, $unread belum dibaca' : 'Notifikasi',
      // Angka di dalam lencana TIDAK dibacakan lagi sebagai simpul tersendiri:
      // tanpa ini pembaca layar mengucapkan "Notifikasi, 3 belum dibaca" lalu
      // "3", dan yang kedua tidak menambah apa pun.
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: AppDurations.fast,
        curve: AppMotion.standard,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            onHighlightChanged: (bool val) {
              if (_pressed != val) {
                setState(() => _pressed = val);
              }
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.borderSubtle, width: 1.0),
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface,
                  ),
                  if (showBadge)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: AnimatedScale(
                        scale: 1.0,
                        duration: AppDurations.normal,
                        curve: Curves.easeOutBack,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
