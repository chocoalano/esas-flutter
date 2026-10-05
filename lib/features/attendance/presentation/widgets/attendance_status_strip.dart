import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';

/// How a status reads at a glance.
enum ReadinessTone { pending, ready, blocked }

/// One fact about readiness.
class AttendanceReadiness {
  const AttendanceReadiness({
    required this.label,
    required this.tone,
    required this.icon,
  });

  final String label;
  final ReadinessTone tone;
  final IconData icon;
}

/// The readiness line under the viewport.
///
/// Two facts at most, and only ones that are actually known. The temptation on a
/// screen like this is a row of five badges — camera, location, network, shift,
/// account — and what that produces is a dashboard nobody reads above the one
/// thing they came to do.
///
/// Location appears **only where the company checks it**. In a workspace with no
/// geofence the handset is never asked where it is, and a chip claiming "lokasi
/// siap" there would be reporting on a permission it never requested.
class AttendanceReadinessStrip extends StatelessWidget {
  const AttendanceReadinessStrip({super.key, required this.statuses});

  final List<AttendanceReadiness> statuses;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.tight,
      children: [for (final status in statuses) _StatusChip(status: status)],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AttendanceReadiness status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final AppTone tone = switch (status.tone) {
      ReadinessTone.ready => palette.success,
      ReadinessTone.pending => palette.neutral,
      ReadinessTone.blocked => palette.warning,
    };

    return Semantics(
      // Never colour alone: the dot has a shape difference too, and the state
      // is spoken.
      label:
          '${status.label}, ${switch (status.tone) {
            ReadinessTone.ready => 'siap',
            ReadinessTone.pending => 'sedang diperiksa',
            ReadinessTone.blocked => 'bermasalah',
          }}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (status.tone) {
              ReadinessTone.ready => Icons.check_circle_rounded,
              ReadinessTone.pending => Icons.more_horiz_rounded,
              ReadinessTone.blocked => Icons.error_outline_rounded,
            },
            size: AppIconSizes.sm,
            color: tone.foreground,
          ),
          const SizedBox(width: AppSpacing.tight),
          Text(
            status.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
