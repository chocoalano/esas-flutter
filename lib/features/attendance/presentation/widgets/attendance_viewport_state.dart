import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import 'attendance_camera_viewport.dart';

/// How loud a viewport state is.
enum ViewportTone { neutral, brand, warning, danger, success }

/// Everything the camera viewport says when it is not showing a camera.
///
/// One widget for every one of them — preparing, permission, no camera, a
/// refused code, a refused clock, a confirmed one — because they occupy the same
/// rectangle and differ only in icon, words and the two buttons underneath. Six
/// bespoke layouts in the same 300 pixels is six chances for them to drift.
///
/// It fills the viewport and no more. The page around it keeps its header, its
/// method selector and its bottom navigation, so an employee who cannot open the
/// camera has not lost the screen — only the picture in it.
class AttendanceViewportState extends StatelessWidget {
  const AttendanceViewportState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = ViewportTone.neutral,
    this.busy = false,
    this.primaryLabel,
    this.primaryIcon,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.footnote,
    this.highlight,
  });

  final IconData icon;
  final String title;
  final String message;
  final ViewportTone tone;

  /// Draws a slim indeterminate bar. For states that are going somewhere on
  /// their own — never for one that is waiting on the person.
  final bool busy;

  /// The action most likely to fix this state. There is exactly one, and which
  /// one it is depends on the cause: Settings for a permanent denial, "Izinkan"
  /// for a permission that has never been asked for.
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// A quiet line under the buttons — what was saved, and where.
  final String? footnote;

  /// One number that deserves to be read at a glance: the clock the server
  /// recorded. Set in monospace, because a time an employee may screenshot as
  /// evidence should not be the smallest thing on the panel.
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AttendanceCameraViewport.overlay;
    final Color accent = switch (tone) {
      ViewportTone.neutral => palette.onOverlay,
      ViewportTone.brand => palette.brandAccent,
      ViewportTone.warning => palette.warning.foreground,
      ViewportTone.danger => palette.danger.foreground,
      ViewportTone.success => palette.success.foreground,
    };

    // The action is always the brand's colour. Tone marks the *state* — on the
    // icon and in the words — and a filled amber or red button under a sentence
    // that already says "warning" shouts the same thing twice.
    final Color action = palette.brandAccent;

    return Container(
      color: palette.overlayScrim,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: AppRadii.xxlAll,
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Icon(icon, size: AppIconSizes.xxl, color: accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: palette.onOverlay,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.onOverlayMuted,
              ),
            ),
            if (highlight != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                highlight!,
                style: AppTypography.dataLarge(color: palette.onOverlay),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: AppRadii.pillAll,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: accent,
                    backgroundColor: accent.withValues(alpha: 0.18),
                    semanticsLabel: title,
                  ),
                ),
              ),
            ],
            if (primaryLabel != null && onPrimary != null) ...[
              const SizedBox(height: AppSpacing.xl),
              _OverlayButton(
                label: primaryLabel!,
                icon: primaryIcon,
                accent: action,
                onPressed: onPrimary!,
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              TextButton(
                onPressed: onSecondary,
                style: TextButton.styleFrom(
                  foregroundColor: palette.onOverlay,
                  minimumSize: const Size(0, 44),
                ),
                child: Text(secondaryLabel!),
              ),
            ],
            if (footnote != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                footnote!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.onOverlayMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A filled button that has to win against a camera image rather than a card.
class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.label,
    required this.accent,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = FilledButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: AttendanceCameraViewport.overlay.surfaceSubtle,
      minimumSize: const Size(0, 46),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    );

    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: AppIconSizes.lg),
      label: Text(label),
    );
  }
}
