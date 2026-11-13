import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_section_header.dart';
import '../../data/models/schedule_calendar.dart';
import '../controllers/schedule_calendar_controller.dart';

const List<String> _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const List<String> _dayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const List<String> _weekdayHeaders = [
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min',
];

class ScheduleCalendarView extends GetView<ScheduleCalendarController> {
  const ScheduleCalendarView({super.key});

  static String formatMonthYear(DateTime d) {
    final monthName = _monthNames[d.month - 1];
    return '$monthName ${d.year}';
  }

  static String formatFullDate(DateTime d) {
    final dayName = _dayNames[d.weekday - 1];
    final monthName = _monthNames[d.month - 1];
    return '$dayName, ${d.day} $monthName ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender & Jadwal Shift'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() {
            final isCurrentMonth =
                controller.currentMonth.value.year == controller.today.year &&
                controller.currentMonth.value.month == controller.today.month;
            final isCurrentDay =
                controller.selectedDate.value.year == controller.today.year &&
                controller.selectedDate.value.month == controller.today.month &&
                controller.selectedDate.value.day == controller.today.day;

            if (isCurrentMonth && isCurrentDay) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: TextButton.icon(
                onPressed: controller.goToToday,
                icon: const Icon(Icons.today_rounded, size: 18),
                label: const Text('Hari Ini'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  textStyle: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        ],
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
                      onPressed: () => controller.loadSchedule(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final calendar = controller.calendar.value;
          final holidays = calendar?.holidays ?? const [];

          return RefreshIndicator(
            onRefresh: () => controller.loadSchedule(),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              children: [
                // 1. Month Navigator
                _MonthNavigator(controller: controller),
                const SizedBox(height: AppSpacing.md),

                // 2. Calendar Grid Card
                _CalendarGridCard(controller: controller),
                const SizedBox(height: AppSpacing.lg),

                // 3. Selected Day Inspector
                _SelectedDayInspector(controller: controller),
                const SizedBox(height: AppSpacing.lg),

                // 4. Monthly Holidays Summary (if any)
                if (holidays.isNotEmpty) ...[
                  AppSectionHeader(
                    title: 'Hari Libur Bulan Ini',
                    subtitle: '${holidays.length} hari libur nasional tercatat',
                    dense: true,
                    naturalCase: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final holiday in holidays)
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
                              color: palette.warning.foreground,
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
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Navigator bar for switching months.
class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({required this.controller});

  final ScheduleCalendarController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Obx(() {
      final currentMonth = controller.currentMonth.value;
      final monthTitle = ScheduleCalendarView.formatMonthYear(currentMonth);

      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: palette.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Bulan sebelumnya',
              onPressed: controller.previousMonth,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  monthTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Bulan berikutnya',
              onPressed: controller.nextMonth,
            ),
          ],
        ),
      );
    });
  }
}

/// Calendar Grid Card displaying days of the week, calendar cells, and legend.
class _CalendarGridCard extends StatelessWidget {
  const _CalendarGridCard({required this.controller});

  final ScheduleCalendarController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return AppCard(
      child: Obx(() {
        final currentMonth = controller.currentMonth.value;
        final selectedDate = controller.selectedDate.value;
        final today = controller.today;

        final year = currentMonth.year;
        final month = currentMonth.month;

        // First day of current month (1..7, where 1 is Monday, 7 is Sunday)
        final firstDayOfMonth = DateTime.utc(year, month, 1);
        final daysInMonth = DateTime.utc(year, month + 1, 0).day;

        // Weekday offset (Mon = 0, Sun = 6)
        final leadingCount = (firstDayOfMonth.weekday - 1) % 7;
        final prevMonthLastDay = DateTime.utc(year, month, 0).day;

        final totalActiveCells = leadingCount + daysInMonth;
        final trailingCount = (7 - (totalActiveCells % 7)) % 7;
        final totalCells = totalActiveCells + trailingCount;
        final numRows = totalCells ~/ 7;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Weekday Headers
            Row(
              children: [
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        _weekdayHeaders[i],
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: i >= 5
                              ? palette.danger.foreground
                              : palette.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(color: palette.borderSubtle, height: 1),
            const SizedBox(height: AppSpacing.sm),

            // Calendar Grid Rows
            for (int row = 0; row < numRows; row++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    for (int col = 0; col < 7; col++) ...[
                      Expanded(
                        child: _buildDayCell(
                          context: context,
                          cellIndex: row * 7 + col,
                          leadingCount: leadingCount,
                          daysInMonth: daysInMonth,
                          prevMonthLastDay: prevMonthLastDay,
                          year: year,
                          month: month,
                          selectedDate: selectedDate,
                          today: today,
                          colIndex: col,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.md),
            Divider(color: palette.borderSubtle, height: 1),
            const SizedBox(height: AppSpacing.sm),

            // Legend
            _buildLegend(context),
          ],
        );
      }),
    );
  }

  Widget _buildDayCell({
    required BuildContext context,
    required int cellIndex,
    required int leadingCount,
    required int daysInMonth,
    required int prevMonthLastDay,
    required int year,
    required int month,
    required DateTime selectedDate,
    required DateTime today,
    required int colIndex,
  }) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final isLeading = cellIndex < leadingCount;
    final isTrailing = cellIndex >= leadingCount + daysInMonth;
    final isCurrentMonth = !isLeading && !isTrailing;

    late final DateTime cellDate;
    late final int displayDay;

    if (isLeading) {
      displayDay = prevMonthLastDay - (leadingCount - 1 - cellIndex);
      cellDate = DateTime.utc(year, month - 1, displayDay);
    } else if (isTrailing) {
      displayDay = cellIndex - (leadingCount + daysInMonth) + 1;
      cellDate = DateTime.utc(year, month + 1, displayDay);
    } else {
      displayDay = cellIndex - leadingCount + 1;
      cellDate = DateTime.utc(year, month, displayDay);
    }

    final isSelected =
        selectedDate.year == cellDate.year &&
        selectedDate.month == cellDate.month &&
        selectedDate.day == cellDate.day;

    final isToday =
        today.year == cellDate.year &&
        today.month == cellDate.month &&
        today.day == cellDate.day;

    final schedule = controller.scheduleFor(cellDate);
    final holiday = controller.holidayFor(cellDate);

    // Color indicators
    Color? indicatorColor;
    if (holiday != null || (schedule?.isHoliday ?? false)) {
      indicatorColor = palette.warning.foreground;
    } else if (schedule?.isLeave ?? false) {
      indicatorColor = palette.info.foreground;
    } else if (schedule?.isDayOff ?? false) {
      indicatorColor = palette.neutral.foreground;
    } else if (schedule?.isWorkday ?? false) {
      indicatorColor = theme.colorScheme.primary;
    }

    // Cell text color
    Color textColor;
    if (isSelected) {
      textColor = theme.colorScheme.onPrimary;
    } else if (!isCurrentMonth) {
      textColor = palette.textMuted.withValues(alpha: 0.35);
    } else if (isToday) {
      textColor = theme.colorScheme.primary;
    } else if (colIndex >= 5) {
      textColor = palette.danger.foreground;
    } else {
      textColor = theme.colorScheme.onSurface;
    }

    return InkWell(
      onTap: () => controller.selectDate(cellDate),
      borderRadius: AppRadii.mdAll,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : isToday
              ? palette.brandSubtle
              : Colors.transparent,
          borderRadius: AppRadii.mdAll,
          border: isToday && !isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$displayDay',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected || isToday
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            if (indicatorColor != null)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.onPrimary : indicatorColor,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.center,
      children: [
        _LegendItem(color: theme.colorScheme.primary, label: 'Kerja'),
        _LegendItem(color: palette.neutral.foreground, label: 'Libur'),
        _LegendItem(color: palette.warning.foreground, label: 'Libur Nasional'),
        _LegendItem(color: palette.info.foreground, label: 'Cuti'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: palette.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Selected Day Inspector Card showing shift, timing, holidays, or off day.
class _SelectedDayInspector extends StatelessWidget {
  const _SelectedDayInspector({required this.controller});

  final ScheduleCalendarController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Obx(() {
      final selectedDate = controller.selectedDate.value;
      final schedule = controller.selectedSchedule;
      final holiday = controller.selectedHoliday;

      final formattedDate = ScheduleCalendarView.formatFullDate(selectedDate);
      final isToday =
          selectedDate.year == controller.today.year &&
          selectedDate.month == controller.today.month &&
          selectedDate.day == controller.today.day;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: 'Detail Jadwal',
            subtitle: formattedDate,
            dense: true,
            naturalCase: true,
            trailing: isToday
                ? const AppBadge(
                    label: 'Hari Ini',
                    tone: AppBadgeTone.brand,
                    dense: true,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Holiday banner if present
                if (holiday != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: palette.warning.background,
                      borderRadius: AppRadii.mdAll,
                      border: Border.all(color: palette.warning.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.celebration_rounded,
                          size: 20,
                          color: palette.warning.foreground,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            holiday.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: palette.warning.foreground,
                            ),
                          ),
                        ),
                        const AppBadge(
                          label: 'Libur Nasional',
                          tone: AppBadgeTone.warning,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // Schedule details
                if (schedule != null) ...[
                  _buildScheduleContent(context, schedule),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Center(
                      child: Text(
                        'Tidak ada jadwal roster khusus untuk tanggal ini.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildScheduleContent(
    BuildContext context,
    ScheduleCalendarItem item,
  ) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final isOff = item.isDayOff;
    final isHoliday = item.isHoliday;
    final isLeave = item.isLeave;
    final isWorkday = item.isWorkday;

    final title =
        item.shift ??
        (isLeave
            ? 'Cuti Karyawan'
            : isOff
            ? 'Hari Libur / Off'
            : isHoliday
            ? 'Libur Nasional'
            : 'Jadwal Standar');

    final AppBadgeTone badgeTone = isWorkday
        ? AppBadgeTone.brand
        : isLeave
        ? AppBadgeTone.info
        : isHoliday
        ? AppBadgeTone.warning
        : AppBadgeTone.neutral;

    final String badgeLabel = isWorkday
        ? 'Kerja'
        : isLeave
        ? 'Cuti'
        : isHoliday
        ? 'Libur Nasional'
        : 'Libur Rutin';

    final IconData mainIcon = isOff
        ? Icons.weekend_outlined
        : isHoliday
        ? Icons.celebration_outlined
        : isLeave
        ? Icons.beach_access_outlined
        : Icons.work_outline;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isWorkday ? palette.brandSubtle : palette.surfaceSubtle,
            borderRadius: AppRadii.lgAll,
          ),
          alignment: Alignment.center,
          child: Icon(
            mainIcon,
            color: isWorkday
                ? theme.colorScheme.primary
                : palette.textMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              if (item.startsAt != null && item.endsAt != null)
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: palette.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.startsAt} - ${item.endsAt}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  isOff
                      ? 'Hari libur / istirahat berkala'
                      : isHoliday
                      ? 'Hari libur resmi'
                      : isLeave
                      ? 'Izin cuti disetujui'
                      : 'Jam kerja fleksibel/standar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
            ],
          ),
        ),
        AppBadge(
          label: badgeLabel,
          tone: badgeTone,
          dense: true,
        ),
      ],
    );
  }
}
