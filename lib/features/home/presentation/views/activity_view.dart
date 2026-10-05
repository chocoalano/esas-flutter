import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:esas/features/home/data/models/activity_log.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/activity_controller.dart';

/// Log aktivitas akun.
///
/// Ini layar audit — isinya teknis dengan sengaja (alamat IP, id perangkat,
/// metode HTTP), karena gunanya adalah menjawab "siapa mengubah apa, dari
/// mana". Yang diperbaiki bukan isinya, melainkan hierarkinya: nama orang naik
/// menjadi judul, tindakan menjadi lencana, dan sisanya menjadi metadata
/// monospace yang bisa dibandingkan antarbaris.
class ActivityView extends GetView<ActivityController> {
  const ActivityView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: () => Get.offAllNamed(HomeRoutes.home),
        ),
        title: const Text('Aktivitas'),
        titleSpacing: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.lists.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: AppSkeletonList(count: 4),
          );
        }

        if (controller.lists.isEmpty) {
          return const AppEmptyState(
            icon: Icons.history_rounded,
            title: 'Belum ada aktivitas',
            message: 'Setiap perubahan pada akun Anda akan tercatat di sini.',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.resetAndFetch,
          child: ListView.separated(
            controller: controller.scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.bottomSafe,
            ),
            itemCount: controller.lists.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index < controller.lists.length) {
                return _ActivityCard(item: controller.lists[index]);
              }
              return Obx(
                () => controller.isLoadMore.value
                    ? const AppSkeletonRow()
                    : const SizedBox.shrink(),
              );
            },
          ),
        );
      }),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item});

  final ActivityLog item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final Map<String, dynamic> payload = item.payload;
    final String name = (payload['name'] ?? '—').toString();
    final String nip = (payload['nip'] ?? '—').toString();
    final String email = (payload['email'] ?? '—').toString();
    final String deviceId = (payload['device_id'] ?? '—').toString();
    final String action = item.action;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppBadge(
                label: _actionLabel(action),
                tone: _toneFor(action),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: palette.borderSubtle),
          const SizedBox(height: AppSpacing.md),

          _MetaGrid(
            entries: [
              ('NIP', nip),
              ('Metode', item.method),
              ('IP', item.ipAddress),
              ('Perangkat', deviceId),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: AppIconSizes.xs,
                color: palette.textMuted,
              ),
              const SizedBox(width: AppSpacing.tight),
              // `Flexible`: stempel waktu lengkap lebih lebar daripada kartu
              // pada 320dp dengan skala teks 1,5, dan sebuah tanggal tidak
              // boleh dipotong — jadi ia membungkus.
              Flexible(
                child: Text(
                  DateFormatter.timestamp(item.createdAt, 'd MMM yyyy • HH:mm'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tindakan datang sebagai kata kerja Inggris dari server (`created`,
  /// `login`). Ini layar yang dibaca staf pabrik, jadi kodenya diterjemahkan;
  /// yang tidak dikenali ditampilkan sebagai kata biasa, bukan sebagai
  /// konstanta huruf besar.
  static String _actionLabel(String action) {
    switch (action.toLowerCase()) {
      case 'created':
        return 'Dibuat';
      case 'updated':
        return 'Diperbarui';
      case 'deleted':
        return 'Dihapus';
      case 'login':
        return 'Masuk';
      case 'logout':
        return 'Keluar';
      case 'restored':
        return 'Dipulihkan';
      default:
        return action.isEmpty
            ? '—'
            : action[0].toUpperCase() + action.substring(1).toLowerCase();
    }
  }

  static AppBadgeTone _toneFor(String action) {
    switch (action.toLowerCase()) {
      case 'created':
      case 'login':
        return AppBadgeTone.success;
      case 'updated':
        return AppBadgeTone.info;
      case 'deleted':
      case 'logout':
        return AppBadgeTone.danger;
      default:
        return AppBadgeTone.neutral;
    }
  }
}

/// Metadata teknis dalam dua kolom.
///
/// Nilainya monospace supaya alamat IP dan id perangkat bisa dibandingkan
/// antarbaris secara sekilas — yang persis merupakan alasan orang membuka log
/// audit.
class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.entries});

  final List<(String, String)> entries;

  /// Setengah lebar isi kartu, dikurangi jarak antarkolom. Angka 96 yang
  /// dipakai sebelumnya menjumlahkan margin halaman dan padding kartu secara
  /// hafalan, dan meleset begitu salah satunya berubah.
  static double _columnWidth(BuildContext context) {
    final double content =
        MediaQuery.of(context).size.width -
        (AppSpacing.page * 2) -
        (AppSpacing.lg * 2);

    return (content - AppSpacing.md) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Wrap(
      runSpacing: AppSpacing.md,
      children: [
        for (final entry in entries)
          SizedBox(
            // Dua kolom di dalam kartu, dihitung dari lebar kartunya sendiri.
            width: _columnWidth(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.$1.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  entry.$2,
                  style: AppTypography.dataSmall(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
