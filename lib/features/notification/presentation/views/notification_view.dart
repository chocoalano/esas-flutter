import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/ui/components/custom_bottom_navbar.dart';
import 'package:esas/core/ui/dialogs/app_dialogs.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/notification.dart';
import '../../data/services/notification_sync_service.dart';
import '../controllers/notification_controller.dart';

/// Kotak masuk.
///
/// Tiga hal yang membedakannya dari daftar kartu yang seragam:
///
/// * **Belum dibaca punya bentuk, bukan hanya warna.** Setiap baris membawa rel
///   3px di tepi kirinya; pada yang belum dibaca rel itu hijau brand, pada yang
///   sudah dibaca ia hanya garis abu — geometrinya sama, jadi kolomnya tetap
///   rata dan yang berubah adalah bobotnya. Titik brand dan judul yang lebih
///   tebal tetap menemaninya, supaya belum-dibaca tidak pernah dibawa warna
///   sendirian.
/// * **Dikelompokkan per hari.** "HARI INI" dan "KEMARIN" menjawab pertanyaan
///   yang sebenarnya diajukan orang saat membuka kotak masuk, dan hari-hari
///   sebelumnya ditulis tanggalnya. Pengelompokannya memakai kalender
///   workspace, bukan kalender ponsel.
/// * **Gagal memuat bukan kotak masuk kosong.** Cabang gagal diperiksa lebih
///   dulu daripada cabang kosong; sebelumnya kegagalan jaringan disajikan
///   sebagai kabar bahwa tidak ada notifikasi sama sekali.
class NotificationView extends GetView<NotificationController> {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        confirmExitApp(context);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Notifikasi')),
        body: Column(
          children: [
            const _InboxStrip(),
            Expanded(child: Obx(() => _body(context))),
          ],
        ),
        bottomNavigationBar: Obx(
          () => CustomBottomNavBar(notificationCount: controller.unreadCount),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final rows = controller.notifications;

    // Urutan cabang adalah bagian dari maknanya: halaman pertama yang gagal
    // selalu menghasilkan daftar kosong juga, jadi cabang kosong yang diperiksa
    // lebih dulu akan menelan setiap kegagalan tanpa sisa.
    final String? error = controller.errorMessage.value;
    if (error != null && rows.isEmpty) {
      return AppErrorState(
        message: error,
        onRetry: controller.refreshNotifications,
      );
    }

    if (controller.isLoading.value && rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.lg),
        child: AppSkeletonList(count: 5),
      );
    }

    if (rows.isEmpty) {
      final Widget empty = controller.unreadOnly.value
          ? const AppEmptyState(
              icon: Icons.mark_email_read_outlined,
              title: 'Semua sudah dibaca',
              message:
                  'Tidak ada notifikasi yang belum dibaca. Matikan saringan '
                  'untuk melihat seluruh kotak masuk.',
            )
          : const AppEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Tidak ada notifikasi',
              message:
                  'Pemberitahuan tentang pengajuan dan absensi Anda akan '
                  'muncul di sini.',
            );

      // Tetap bisa ditarik untuk menyegarkan. Keadaan kosong adalah keadaan
      // yang paling sering ingin dicoba ulang orang, dan tanpa fisika ini
      // gestur tariknya tidak pernah sampai ke [RefreshIndicator].
      return RefreshIndicator(
        onRefresh: controller.refreshNotifications,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: empty,
            ),
          ),
        ),
      );
    }

    final entries = _groupByDay(rows);
    final bool showTail = controller.isMoreLoading.value;

    return RefreshIndicator(
      onRefresh: controller.refreshNotifications,
      child: ListView.builder(
        controller: controller.scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.lg,
          AppSpacing.page,
          AppSpacing.bottomSafe,
        ),
        itemCount: entries.length + (showTail ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == entries.length) {
            return const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: AppSkeletonRow(),
            );
          }

          final entry = entries[index];

          return switch (entry) {
            _DayHeader(:final label, :final count) => Padding(
              padding: EdgeInsets.only(
                top: index == 0 ? 0 : AppSpacing.xl,
                bottom: AppSpacing.sm,
              ),
              child: AppSectionHeader(
                title: label,
                dense: true,
                showDivider: true,
                padding: EdgeInsets.zero,
                trailing: Text(
                  '$count',
                  style: AppTypography.dataSmall(
                    color: Theme.of(context).palette.textMuted,
                  ),
                ),
              ),
            ),
            _InboxRow(:final notification) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _NotificationTile(
                notification: notification,
                onTap: () async {
                  await controller.markAsRead(notification.id);
                  if (Get.isRegistered<NotificationSyncService>()) {
                    Get.find<NotificationSyncService>().open(
                      notification.data.payload,
                    );
                  }
                },
              ),
            ),
          };
        },
      ),
    );
  }
}

/// Baris ringkas di atas daftar: berapa yang menunggu, dan saringannya.
class _InboxStrip extends GetView<NotificationController> {
  const _InboxStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.page,
        right: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.borderSubtle)),
      ),
      // `Wrap`, bukan `Row`: pada 320dp dengan skala teks 1,5 tombol saringan
      // memakan hampir seluruh lebar dan menyisakan sembilan piksel untuk
      // lencananya — cukup sempit sampai ikon lencana itu sendiri meluap.
      // Keduanya kini turun ke barisnya masing-masing alih-alih saling desak.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: AppSpacing.xs,
        children: [
          Obx(() {
            if (controller.errorMessage.value != null &&
                controller.notifications.isEmpty) {
              return const SizedBox.shrink();
            }

            final int unread = controller.unreadCount;

            return unread == 0
                ? const AppBadge(
                    label: 'Semua sudah dibaca',
                    icon: Icons.done_all_rounded,
                  )
                : AppBadge(
                    label: '$unread belum dibaca',
                    tone: AppBadgeTone.brand,
                    icon: Icons.mark_email_unread_outlined,
                  );
          }),
          Obx(
            () => TextButton.icon(
              onPressed: () =>
                  controller.setUnreadOnly(!controller.unreadOnly.value),
              icon: Icon(
                controller.unreadOnly.value
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: AppIconSizes.lg,
              ),
              label: const Text('Belum dibaca'),
              // Tombol teks bawaan tema bertarget 36dp karena kebanyakan
              // dipakai di dalam kalimat; ini saringan tersendiri, jadi
              // targetnya naik ke 48dp.
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris kotak masuk.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final bool isRead = notification.isRead;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rel penanda. Selalu ada, jadi kolom teks di kanan tidak pernah
            // bergeser saat sebuah baris berpindah dari belum dibaca ke sudah.
            SizedBox(
              width: 3,
              child: ColoredBox(
                color: isRead
                    ? palette.borderSubtle
                    : theme.colorScheme.primary,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconBox(
                      icon: _iconFor(notification.type, isRead: isRead),
                      size: 34,
                      foreground: isRead
                          ? palette.textMuted
                          : theme.colorScheme.primary,
                      background: isRead
                          ? palette.surfaceSubtle
                          : palette.brandSubtle,
                      borderColor: isRead ? palette.borderSubtle : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.data.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                    color: isRead
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isRead) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: AppStatusDot(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.tight),
                          Text(
                            notification.data.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _relativeTime(notification.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.textMuted,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ikon menurut jenis notifikasi.
  ///
  /// `type` adalah nama kelas PHP di sisi server, jadi ia tidak pernah
  /// ditampilkan — ia hanya dibaca untuk memilih ikon. Kata kunci dicocokkan,
  /// bukan nama penuhnya, supaya perubahan namespace di server tidak diam-diam
  /// mengosongkan seluruh kolom ikon.
  static IconData _iconFor(String type, {required bool isRead}) {
    final String key = type.toLowerCase();

    if (key.contains('permit') ||
        key.contains('izin') ||
        key.contains('cuti')) {
      return Icons.assignment_outlined;
    }
    if (key.contains('approv') || key.contains('persetujuan')) {
      return Icons.how_to_reg_outlined;
    }
    if (key.contains('attendance') || key.contains('absen')) {
      return Icons.qr_code_scanner_rounded;
    }
    if (key.contains('announce') || key.contains('pengumuman')) {
      return Icons.campaign_outlined;
    }
    if (key.contains('password') || key.contains('account')) {
      return Icons.lock_outline_rounded;
    }

    return isRead
        ? Icons.mark_email_read_outlined
        : Icons.mark_email_unread_outlined;
  }

  /// Waktu relatif untuk yang baru, tanggal penuh untuk yang lama.
  ///
  /// "3 menit lalu" lebih berguna daripada jam persis bagi sesuatu yang baru
  /// terjadi; sebaliknya "9 hari lalu" memaksa orang berhitung mundur, jadi di
  /// atas seminggu tanggalnya ditulis apa adanya.
  ///
  /// Selisihnya dihitung pada jam workspace, bukan jam ponsel: notifikasi
  /// dicap waktu oleh server, dan ponsel yang mengembara satu zona akan
  /// mengubah setiap "baru saja" menjadi "7 jam lalu".
  static String _relativeTime(DateTime instant) {
    final clock = WorkspaceClock.current;
    final Duration diff = clock.now().difference(clock.wallClock(instant));

    if (diff.isNegative) return DateFormatter.timestamp(instant, 'd MMM yyyy');
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormatter.timestamp(instant, 'd MMM yyyy');
  }
}

/// Satu baris daftar: penanda hari, atau sebuah notifikasi.
sealed class _InboxEntry {
  const _InboxEntry();
}

class _DayHeader extends _InboxEntry {
  const _DayHeader({required this.label, required this.count});

  final String label;
  final int count;
}

class _InboxRow extends _InboxEntry {
  const _InboxRow(this.notification);

  final NotificationModel notification;
}

/// Mengelompokkan baris per hari kalender workspace.
///
/// Harinya diambil dari [WorkspaceClock], bukan dari `DateTime` ponsel: sebuah
/// notifikasi yang dikirim pukul 23.30 di pabrik tidak boleh muncul di bawah
/// "besok" hanya karena ponselnya diset satu zona ke timur.
List<_InboxEntry> _groupByDay(List<NotificationModel> rows) {
  final clock = WorkspaceClock.current;
  final DateTime today = clock.today();

  final groups = <DateTime, List<NotificationModel>>{};

  for (final row in rows) {
    final wall = clock.wallClock(row.createdAt);
    final day = DateTime.utc(wall.year, wall.month, wall.day);

    groups.putIfAbsent(day, () => <NotificationModel>[]).add(row);
  }

  final entries = <_InboxEntry>[];

  groups.forEach((day, dayRows) {
    final int distance = today.difference(day).inDays;
    final String label = switch (distance) {
      0 => 'Hari ini',
      1 => 'Kemarin',
      _ => DateFormatter.timestamp(dayRows.first.createdAt, 'd MMMM yyyy'),
    };

    entries.add(_DayHeader(label: label, count: dayRows.length));
    entries.addAll(dayRows.map(_InboxRow.new));
  });

  return entries;
}
