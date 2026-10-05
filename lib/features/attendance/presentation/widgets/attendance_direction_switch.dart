import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/models/attendance_context.dart';

/// Masuk or pulang, chosen by the person doing it.
///
/// ## Why this is a choice and not a readout
///
/// The direction used to be `next_presence` and nothing else — the roster's
/// answer, taken as final. That is right nearly always and wrong in the cases
/// that matter most to the person standing there: they clocked in on a
/// colleague's handset, a shift was swapped after the roster was drawn, a night
/// shift rolled over midnight. In each of those the app insisted on a direction
/// the employee knew was wrong, and offered no way to say so.
///
/// ## What it is not
///
/// It is not a licence. The server still refuses `already_clocked_in`,
/// `no_clock_in` and `already_clocked_out` inside one transaction with the row
/// locked, so the worst a wrong choice costs is a refusal — never a wrong
/// record. What the app owes in exchange is a warning *before* the attempt,
/// because a refusal that arrives after a single-use QR code has been spent is
/// a refusal that cost something.
///
/// Deliberately smaller and quieter than the method selector above the camera.
/// Two controls of equal weight would read as two equally consequential
/// decisions, and this one is a correction to a default that is usually right.
class AttendanceDirectionSwitch extends StatelessWidget {
  const AttendanceDirectionSwitch({
    super.key,
    required this.selected,
    required this.expected,
    required this.enabled,
    required this.onChoose,
  });

  /// The direction this attempt will use — the choice, or the roster's answer.
  final PresenceDirection? selected;

  /// What `next_presence` says, for marking the default.
  final PresenceDirection? expected;

  final bool enabled;
  final ValueChanged<PresenceDirection> onChoose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final direction in PresenceDirection.values)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.tight),
            child: _Pill(
              direction: direction,
              selected: direction == selected,
              // The roster's answer keeps a mark even when something else is
              // chosen, so "what the server expects" never becomes invisible.
              isDefault: direction == expected,
              enabled: enabled,
              onTap: () => onChoose(direction),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.direction,
    required this.selected,
    required this.isDefault,
    required this.enabled,
    required this.onTap,
  });

  final PresenceDirection direction;
  final bool selected;
  final bool isDefault;
  final bool enabled;
  final VoidCallback onTap;

  /// "Absen masuk" is the full sentence; on a pill it is one word.
  String get _short =>
      direction == PresenceDirection.clockIn ? 'Masuk' : 'Pulang';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final Color foreground = switch ((selected, enabled)) {
      (true, _) => palette.brandAccent,
      (false, true) => palette.textMuted,
      (false, false) => palette.onDisabled,
    };

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      // Spoken rather than left to the fill: which one the roster expects is a
      // fact a screen reader user needs as much as anybody.
      label:
          'Absen ${_short.toLowerCase()}'
          '${isDefault ? ', sesuai jadwal' : ''}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled && !selected ? onTap : null,
          borderRadius: AppRadii.pillAll,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppMotion.standard,
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected ? palette.brandSubtle : Colors.transparent,
              borderRadius: AppRadii.pillAll,
              border: Border.all(
                color: selected ? palette.brandAccent : palette.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDefault) ...[
                  Icon(
                    Icons.event_available_rounded,
                    size: AppIconSizes.xs,
                    color: foreground,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Text(
                  _short,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

/// One line, only when the choice disagrees with the roster.
///
/// Said before the attempt rather than after it. The refusal that follows a
/// wrong choice is correct, but it arrives once a single-use code has already
/// been spent — and a code spent on a refusal is a code the person has to go
/// and fetch again.
class AttendanceDirectionNote extends StatelessWidget {
  const AttendanceDirectionNote({
    super.key,
    required this.show,
    required this.expected,
  });

  final bool show;
  final PresenceDirection? expected;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = theme.palette;

    final String sentence = expected == null
        ? 'Jadwal Anda hari ini sudah lengkap, jadi absensi ini mungkin ditolak '
              'server.'
        : 'Jadwal Anda menunjukkan ${expected!.label.toLowerCase()}. Server '
              'dapat menolak pilihan ini.';

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.tight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: AppIconSizes.sm,
            color: palette.warning.foreground,
          ),
          const SizedBox(width: AppSpacing.tight),
          Expanded(
            child: Text(
              sentence,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
