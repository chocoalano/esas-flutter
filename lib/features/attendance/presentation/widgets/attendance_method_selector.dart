import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../controllers/attendance_controller.dart';

/// The two attendance methods, as one compact control.
///
/// A segmented control rather than two large buttons, and the difference is
/// what it says about the choice. Two giant buttons read as two destinations,
/// each with its own consequences; a segment reads as one job with two ways of
/// doing it, which is exactly what QR and face are — alternatives the server
/// allows the same person on the same day.
///
/// ## An unavailable method is shown, and is not pressable
///
/// It would be simpler to hide the face segment for somebody HR has not enrolled
/// yet. It would also be worse: an employee who has heard that the app does face
/// attendance, and who cannot find it, has no way to learn that the answer is
/// "HR has not registered you". So the segment stays, visibly not selectable,
/// and [AttendanceMethodNote] underneath says why in one sentence.
///
/// What must never happen is the third option — a segment that looks live,
/// accepts a tap, and lands on a screen that can only apologise.
class AttendanceMethodSelector extends StatelessWidget {
  const AttendanceMethodSelector({
    super.key,
    required this.active,
    required this.statusOf,
    required this.onSelect,
  });

  final AttendanceMethod active;
  final MethodStatus Function(AttendanceMethod) statusOf;
  final ValueChanged<AttendanceMethod> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: AppRadii.xlAll,
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        children: [
          for (final method in AttendanceMethod.values)
            Expanded(
              child: _Segment(
                method: method,
                selected: method == active,
                enabled: statusOf(method).usable,
                onTap: () => onSelect(method),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AttendanceMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  static const Map<AttendanceMethod, IconData> _icons = {
    AttendanceMethod.qr: Icons.qr_code_scanner_rounded,
    AttendanceMethod.face: Icons.face_retouching_natural_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final Color foreground = switch ((selected, enabled)) {
      (true, _) => theme.colorScheme.onPrimary,
      (false, true) => theme.colorScheme.onSurfaceVariant,
      (false, false) => palette.onDisabled,
    };

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      // Spoken, not merely coloured. The selected segment is told apart by fill,
      // by weight and by this — never by colour alone.
      label: '${method.label}${enabled ? '' : ', belum tersedia'}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled && !selected ? onTap : null,
          borderRadius: AppRadii.lgAll,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppMotion.standard,
            constraints: const BoxConstraints(minHeight: 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected ? palette.brandAccent : Colors.transparent,
              borderRadius: AppRadii.lgAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enabled ? _icons[method] : Icons.lock_outline_rounded,
                  size: AppIconSizes.md,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.tight),
                Flexible(
                  child: Text(
                    method.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

/// One sentence under the selector, when a method is not available.
///
/// Worded for its cause. "Belum terdaftar" is not an error and gets no error
/// colour: nothing is broken, the employee did nothing wrong, and there is
/// nothing for them to retry — the next step is HR's.
class AttendanceMethodNote extends StatelessWidget {
  const AttendanceMethodNote({super.key, required this.status});

  final MethodStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.usable) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = theme.palette;

    final (IconData icon, String text) = switch (status) {
      MethodStatus.notEnrolled => (
        Icons.info_outline_rounded,
        'Wajah Anda belum didaftarkan HR, jadi verifikasi wajah belum bisa dipakai.',
      ),
      MethodStatus.accountDisabled => (
        Icons.lock_outline_rounded,
        'Akun Anda belum diatur untuk mencatat kehadiran. Hubungi HR.',
      ),
      MethodStatus.methodDisabled => (
        Icons.info_outline_rounded,
        'Absensi QR tidak diaktifkan untuk perusahaan Anda.',
      ),
      MethodStatus.available => (Icons.info_outline_rounded, ''),
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSizes.sm, color: palette.textMuted),
          const SizedBox(width: AppSpacing.tight),
          Expanded(
            child: Text(
              text,
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
