import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
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

/// Kotak masuk notifikasi.
///
/// Menyajikan notifikasi aktivitas, perizinan cuti, kehadiran, tugas, slip gaji,
/// dan pengumuman dengan kategorisasi visual yang informatif, tipografi berjenjang,
/// serta segmented control tab ("Semua" & "Belum Dibaca") yang rapi dan terpadu.
class NotificationView extends GetView<NotificationController> {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Title(
      title: 'Notifikasi – Absensas',
      color: Colors.black,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          confirmExitApp(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'Notifikasi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                onPressed: controller.refreshNotifications,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Segarkan',
              ),
            ],
          ),
          body: Column(
            children: [
              const _NotificationTabs(),
              Expanded(child: Obx(() => _body(context))),
            ],
          ),
          bottomNavigationBar: Obx(
            () => CustomBottomNavBar(notificationCount: controller.unreadCount),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final rows = controller.notifications;

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
          ? AppEmptyState(
              icon: Icons.mark_email_read_outlined,
              title: 'Semua sudah dibaca',
              message:
                  'Tidak ada notifikasi yang belum dibaca saat ini. Matikan '
                  'saringan untuk melihat seluruh kotak masuk.',
              actionLabel: 'Tampilkan semua',
              onAction: () => controller.setUnreadOnly(false),
            )
          : const AppEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Belum ada notifikasi',
              message:
                  'Pemberitahuan terkait pengajuan cuti, presensi, dan pengumuman '
                  'kerja Anda akan muncul di sini.',
            );

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
      child: Scrollbar(
        controller: controller.scrollController,
        child: ListView.builder(
          controller: controller.scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
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
                  top: index == 0 ? AppSpacing.xs : AppSpacing.md,
                  bottom: AppSpacing.xs,
                ),
                child: AppSectionHeader(
                  title: label,
                  dense: true,
                  showDivider: true,
                  naturalCase: true,
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
                        refresh: false,
                      );
                    }
                  },
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}

/// Bilah tab segmented control yang rapi, simetris, dan proporsional.
class _NotificationTabs extends GetView<NotificationController> {
  const _NotificationTabs();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Obx(() {
        final bool unreadOnly = controller.unreadOnly.value;
        final int unread = controller.unreadCount;

        return Container(
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.borderSubtle, width: 0.5),
          ),
          child: Row(
            children: <Widget>[
              // Tab 1: Semua
              Expanded(
                child: _SegmentItem(
                  label: 'Semua',
                  isActive: !unreadOnly,
                  onTap: () {
                    if (unreadOnly) controller.setUnreadOnly(false);
                  },
                ),
              ),
              const SizedBox(width: 3),
              // Tab 2: Belum Dibaca
              Expanded(
                child: _SegmentItem(
                  label: 'Belum Dibaca',
                  count: unread > 0 ? unread : null,
                  isActive: unreadOnly,
                  onTap: () {
                    if (!unreadOnly) controller.setUnreadOnly(true);
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final bool isDark = theme.brightness == Brightness.dark;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                    width: 0.8,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? theme.colorScheme.onSurface
                        : palette.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF064E3B)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF059669)
                          : const Color(0xFFA7F3D0),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Metadata visual kategori notifikasi.
class _NotificationMeta {
  const _NotificationMeta({
    required this.category,
    required this.icon,
    required this.iconFg,
    required this.iconBg,
    required this.cardBorder,
    required this.categoryFg,
    required this.categoryBg,
  });

  final String category;
  final IconData icon;
  final Color iconFg;
  final Color iconBg;
  final Color cardBorder;
  final Color categoryFg;
  final Color categoryBg;

  static _NotificationMeta resolve({
    required String type,
    required String title,
    required String message,
    required bool isRead,
    required bool isDark,
    required Color primaryColor,
    required AppPalette palette,
  }) {
    final String t = type.toLowerCase();
    final String h = title.toLowerCase();
    final String m = message.toLowerCase();

    // 1. Slip Gaji / Payroll
    if (t.contains('payslip') ||
        t.contains('salary') ||
        h.contains('gaji') ||
        h.contains('slip')) {
      final fg = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
      final bg = isDark ? const Color(0xFF134E4A) : const Color(0xFFF0FDFA);
      final border = isDark ? const Color(0xFF0F766E) : const Color(0xFF99F6E4);

      return _NotificationMeta(
        category: 'Slip Gaji',
        icon: Icons.payments_outlined,
        iconFg: isRead ? palette.textMuted : fg,
        iconBg: isRead ? palette.surfaceSubtle : bg,
        cardBorder: isRead ? palette.borderSubtle : border,
        categoryFg: fg,
        categoryBg: bg,
      );
    }

    // 2. Persetujuan / Approval Decision
    if (t.contains('approv') ||
        t.contains('decided') ||
        h.contains('persetujuan') ||
        h.contains('status')) {
      final bool isApproved = h.contains('disetujui') ||
          m.contains('disetujui') ||
          h.contains('approved') ||
          m.contains('approved');
      final bool isRejected = h.contains('ditolak') ||
          m.contains('ditolak') ||
          h.contains('rejected') ||
          m.contains('rejected');

      if (isApproved) {
        final fg = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        final bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
        final border = isDark
            ? const Color(0xFF047857)
            : const Color(0xFFA7F3D0);

        return _NotificationMeta(
          category: 'Disetujui',
          icon: Icons.check_circle_outline_rounded,
          iconFg: isRead ? palette.textMuted : fg,
          iconBg: isRead ? palette.surfaceSubtle : bg,
          cardBorder: isRead ? palette.borderSubtle : border,
          categoryFg: fg,
          categoryBg: bg,
        );
      } else if (isRejected) {
        final fg = isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48);
        final bg = isDark ? const Color(0xFF4C0519) : const Color(0xFFFFF1F2);
        final border = isDark
            ? const Color(0xFF9F1239)
            : const Color(0xFFFECDD3);

        return _NotificationMeta(
          category: 'Ditolak',
          icon: Icons.cancel_outlined,
          iconFg: isRead ? palette.textMuted : fg,
          iconBg: isRead ? palette.surfaceSubtle : bg,
          cardBorder: isRead ? palette.borderSubtle : border,
          categoryFg: fg,
          categoryBg: bg,
        );
      } else {
        final fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        final bg = isDark ? const Color(0xFF382305) : const Color(0xFFFFFBEB);
        final border = isDark
            ? const Color(0xFFB45309)
            : const Color(0xFFFDE68A);

        return _NotificationMeta(
          category: 'Persetujuan',
          icon: Icons.how_to_reg_outlined,
          iconFg: isRead ? palette.textMuted : fg,
          iconBg: isRead ? palette.surfaceSubtle : bg,
          cardBorder: isRead ? palette.borderSubtle : border,
          categoryFg: fg,
          categoryBg: bg,
        );
      }
    }

    // 3. Izin, Cuti, Sakit (Permit)
    if (t.contains('permit') ||
        t.contains('izin') ||
        t.contains('cuti') ||
        h.contains('izin') ||
        h.contains('cuti')) {
      final fg = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      final bg = isDark ? const Color(0xFF0C243B) : const Color(0xFFF0F9FF);
      final border = isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD);

      return _NotificationMeta(
        category: 'Izin & Cuti',
        icon: Icons.assignment_outlined,
        iconFg: isRead ? palette.textMuted : fg,
        iconBg: isRead ? palette.surfaceSubtle : bg,
        cardBorder: isRead ? palette.borderSubtle : border,
        categoryFg: fg,
        categoryBg: bg,
      );
    }

    // 4. Pengumuman Resmi
    if (t.contains('announce') ||
        h.contains('pengumuman') ||
        m.contains('pengumuman')) {
      final fg = isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
      final bg = isDark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF);
      final border = isDark ? const Color(0xFF6D28D9) : const Color(0xFFDDD6FE);

      return _NotificationMeta(
        category: 'Pengumuman',
        icon: Icons.campaign_outlined,
        iconFg: isRead ? palette.textMuted : fg,
        iconBg: isRead ? palette.surfaceSubtle : bg,
        cardBorder: isRead ? palette.borderSubtle : border,
        categoryFg: fg,
        categoryBg: bg,
      );
    }

    // 5. Presensi & Kehadiran
    if (t.contains('attendance') ||
        t.contains('absen') ||
        h.contains('absen') ||
        h.contains('presensi')) {
      final fg = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
      final bg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
      final border = isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE);

      return _NotificationMeta(
        category: 'Presensi',
        icon: Icons.qr_code_scanner_rounded,
        iconFg: isRead ? palette.textMuted : fg,
        iconBg: isRead ? palette.surfaceSubtle : bg,
        cardBorder: isRead ? palette.borderSubtle : border,
        categoryFg: fg,
        categoryBg: bg,
      );
    }

    // 6. Tugas Lapangan, MTMS, GAMS, ITMS
    if (t.contains('task') ||
        t.contains('work_order') ||
        t.contains('ticket') ||
        t.contains('itms') ||
        t.contains('mtcms')) {
      final fg = isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
      final bg = isDark ? const Color(0xFF431407) : const Color(0xFFFFF7ED);
      final border = isDark ? const Color(0xFFC2410C) : const Color(0xFFFED7AA);

      return _NotificationMeta(
        category: 'Tugas & Tiket',
        icon: Icons.build_circle_outlined,
        iconFg: isRead ? palette.textMuted : fg,
        iconBg: isRead ? palette.surfaceSubtle : bg,
        cardBorder: isRead ? palette.borderSubtle : border,
        categoryFg: fg,
        categoryBg: bg,
      );
    }

    // 7. Keamanan & Akun
    if (t.contains('password') ||
        t.contains('security') ||
        t.contains('account') ||
        h.contains('keamanan') ||
        h.contains('sandi')) {
      final fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
      final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      final border = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

      return _NotificationMeta(
        category: 'Keamanan',
        icon: Icons.shield_outlined,
        iconFg: isRead ? palette.textMuted : fg,
        iconBg: isRead ? palette.surfaceSubtle : bg,
        cardBorder: isRead ? palette.borderSubtle : border,
        categoryFg: fg,
        categoryBg: bg,
      );
    }

    // Default: Sistem
    final fg = isDark ? primaryColor : const Color(0xFF059669);
    final bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
    final border = isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0);

    return _NotificationMeta(
      category: 'Sistem',
      icon: isRead
          ? Icons.mark_email_read_outlined
          : Icons.mark_email_unread_outlined,
      iconFg: isRead ? palette.textMuted : fg,
      iconBg: isRead ? palette.surfaceSubtle : bg,
      cardBorder: isRead ? palette.borderSubtle : border,
      categoryFg: fg,
      categoryBg: bg,
    );
  }
}

/// Satu kartu notifikasi berdesain modern & informatif.
class _NotificationTile extends StatefulWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final bool isDark = theme.brightness == Brightness.dark;
    final NotificationModel notification = widget.notification;
    final bool isRead = notification.isRead;

    final meta = _NotificationMeta.resolve(
      type: notification.type,
      title: notification.data.title,
      message: notification.data.message,
      isRead: isRead,
      isDark: isDark,
      primaryColor: theme.colorScheme.primary,
      palette: palette,
    );

    return Semantics(
      button: true,
      label:
          '${notification.data.title}, ${isRead ? "sudah dibaca" : "belum dibaca"}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          onHighlightChanged: (bool val) {
            if (_pressed != val) {
              setState(() => _pressed = val);
            }
          },
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1.0,
            duration: AppDurations.fast,
            curve: AppMotion.standard,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRead
                      ? palette.borderSubtle
                      : meta.cardBorder.withValues(alpha: isDark ? 0.45 : 0.65),
                  width: 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Rel penanda status belum dibaca
                      Container(
                        width: 4,
                        color: isRead
                            ? Colors.transparent
                            : theme.colorScheme.primary,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Icon Box Squircle
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: meta.iconBg,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: isRead
                                        ? palette.borderSubtle
                                        : meta.cardBorder.withValues(
                                            alpha: 0.3,
                                          ),
                                    width: 0.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  meta.icon,
                                  size: 19,
                                  color: meta.iconFg,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              // Content Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    // Row 1: Title + Unread Dot
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            notification.data.title,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: isRead
                                                      ? FontWeight.w500
                                                      : FontWeight.w700,
                                                  fontSize: 13.5,
                                                  letterSpacing: -0.2,
                                                  color: isRead
                                                      ? theme
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                      : theme
                                                            .colorScheme
                                                            .onSurface,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!isRead) ...<Widget>[
                                          const SizedBox(width: AppSpacing.sm),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 5,
                                            ),
                                            child: Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color:
                                                    theme.colorScheme.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    // Row 2: Message
                                    Text(
                                      notification.data.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: palette.textMuted,
                                        fontSize: 11.5,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    // Row 3: Category Badge + Relative Time
                                    Row(
                                      children: <Widget>[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isRead
                                                ? (isDark
                                                    ? const Color(0xFF1E293B)
                                                    : const Color(0xFFF1F5F9))
                                                : meta.categoryBg,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          child: Text(
                                            meta.category,
                                            style: TextStyle(
                                              color: isRead
                                                  ? palette.textMuted
                                                  : meta.categoryFg,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '· ${_relativeTime(notification.createdAt)}',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: palette.textMuted,
                                                  fontSize: 10.5,
                                                  letterSpacing: 0.1,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime instant) {
    final clock = WorkspaceClock.current;
    final Duration diff = clock.now().difference(clock.wallClock(instant));

    if (diff.isNegative) return DateFormatter.timestamp(instant, 'd MMM yyyy');
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
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
