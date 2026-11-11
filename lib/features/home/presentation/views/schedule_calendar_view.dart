import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_section_header.dart';
import '../../data/models/schedule_calendar.dart';
import '../controllers/schedule_calendar_controller.dart';

class ScheduleCalendarView extends GetView<ScheduleCalendarController> {
  const ScheduleCalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Shift & Kalender'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (controller.error.value != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: palette.danger.foreground,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      controller.error.value!.message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: controller.loadSchedule,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final calendar = controller.calendar.value;
          if (calendar == null || calendar.schedule.isEmpty) {
            return Center(
              child: Text(
                'Tidak ada jadwal untuk periode ini.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadSchedule,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              children: [
                if (calendar.holidays.isNotEmpty) ...[
                  AppSectionHeader(
                    title: 'Hari Libur Periode Ini',
                    subtitle: '${calendar.holidays.length} hari libur tercatat',
                    dense: true,
                    naturalCase: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final holiday in calendar.holidays)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: palette.brandSubtle,
                          borderRadius: AppRadii.mdAll,
                          border: Border.all(color: palette.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.celebration_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                holiday.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              holiday.date,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: palette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const AppSectionHeader(
                  title: 'Daftar Roster Shift',
                  dense: true,
                  naturalCase: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final item in calendar.schedule) _ScheduleCard(item: item),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.item});

  final ScheduleCalendarItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    // Leave is not a working day either (HOME-11); drawn like a day off.
    final isOff = item.isDayOff || item.isLeave;
    final isHoliday = item.isHoliday;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isOff || isHoliday
                    ? palette.surfaceSubtle
                    : palette.brandSubtle,
                borderRadius: AppRadii.lgAll,
              ),
              alignment: Alignment.center,
              child: Icon(
                isOff
                    ? Icons.weekend_outlined
                    : isHoliday
                    ? Icons.celebration_outlined
                    : Icons.work_outline,
                color: isOff || isHoliday
                    ? palette.textMuted
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.shift ??
                        (item.isLeave
                            ? 'Cuti'
                            : isOff
                            ? 'Hari Libur / Off'
                            : isHoliday
                            ? 'Libur Nasional'
                            : 'Jadwal Standar'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.date,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (item.startsAt != null && item.endsAt != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surfaceSubtle,
                  borderRadius: AppRadii.mdAll,
                ),
                child: Text(
                  '${item.startsAt} - ${item.endsAt}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
