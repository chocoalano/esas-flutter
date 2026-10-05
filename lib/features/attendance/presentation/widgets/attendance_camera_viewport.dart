import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';

/// The one dark rectangle on the page.
///
/// The screen this replaces was a full-bleed camera with everything floating on
/// top of it, so a camera that failed to open turned the *whole page* black —
/// header, controls and all — and the app read as broken rather than as a camera
/// that could not start. Here the darkness is bounded: a rounded canvas with the
/// page's own surface around it, so a viewport in an error state is one panel
/// with a problem on a page that is plainly still working.
///
/// Everything drawn inside it uses the dark palette regardless of the app's
/// theme, because what decides contrast in here is the camera image, not the
/// employee's light/dark preference.
class AttendanceCameraViewport extends StatelessWidget {
  const AttendanceCameraViewport({super.key, required this.child});

  final Widget child;

  /// The palette every layer above the camera reads from. Always the dark one.
  static const AppPalette overlay = AppPalette.dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: Container(
        // The theme's own deep black rather than `Colors.black` written here:
        // `scrim` is the one opaque black both colour schemes declare.
        color: theme.colorScheme.scrim,
        child: Stack(fit: StackFit.expand, children: [child]),
      ),
    );
  }
}

/// Corner markers, a dimmed surround and one instruction.
///
/// Corners rather than a closed 4px box: they mark the area without covering
/// what is being aimed at. The surround is dimmed only slightly — enough to say
/// where to point, not enough to hide a code that is nearly in frame.
class QrScanOverlay extends StatelessWidget {
  const QrScanOverlay({super.key, required this.hint, this.busy = false});

  /// A short line under the frame, when there is something to say.
  final String? hint;

  /// Whether a code is being verified. The corners go quiet, because a frame
  /// still inviting a scan during a submission invites a second one.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AttendanceCameraViewport.overlay;
    final Color accent = palette.brandAccent;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Square, generous, and never taller than the viewport allows. On a
        // 320dp handset this is about 210dp — big enough to aim with, small
        // enough that the instruction below it still fits.
        final double side = _frameSide(constraints);
        final Rect frame = Rect.fromCenter(
          center: Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2 - AppSpacing.lg,
          ),
          width: side,
          height: side,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ApertureScrim(
                  aperture: RRect.fromRectAndRadius(
                    frame,
                    const Radius.circular(AppRadii.xxl),
                  ),
                  colour: palette.overlayScrim,
                ),
              ),
            ),
            Positioned.fromRect(
              rect: frame,
              child: _Corners(
                colour: busy ? palette.onOverlayMuted : accent,
                busy: busy,
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: frame.bottom + AppSpacing.xl,
              child: _Instruction(
                icon: Icons.qr_code_2_rounded,
                accent: accent,
                title: busy
                    ? 'QR ditemukan'
                    : 'Arahkan QR absensi ke dalam bingkai',
                // The scanner reads continuously; saying so stops people
                // hunting for a shutter button that does not exist.
                subtitle: busy
                    ? 'Memverifikasi ke server…'
                    : (hint ?? 'Pemindaian dilakukan otomatis.'),
                theme: theme,
              ),
            ),
          ],
        );
      },
    );
  }

  /// How big the aiming square may be here.
  ///
  /// The smaller of what the width allows and what is left after the
  /// instruction block, then held between a floor and a ceiling. Written as a
  /// `min` and a single clamp rather than a clamp inside a clamp: the nested
  /// version threw `ArgumentError` outright on a 320×568 handset, because a
  /// short viewport made the upper bound smaller than the lower one.
  static double _frameSide(BoxConstraints constraints) {
    final double byWidth = constraints.maxWidth * 0.66;
    final double byHeight = constraints.maxHeight - 150;

    return math.min(byWidth, byHeight).clamp(120.0, 300.0);
  }
}

/// An oval guide, the movement being asked for, and how far it has got.
///
/// A different anatomy from [QrScanOverlay] on purpose: an employee must be able
/// to tell the two modes apart without reading a word. A square with corners is
/// "hold a code here"; an upright oval is "put your face here".
class LivenessOverlay extends StatelessWidget {
  const LivenessOverlay({
    super.key,
    required this.headline,
    this.instruction,
    this.hint,
    this.progress,
    this.step,
    this.totalSteps,
    this.settled = true,
  });

  /// What is happening — "Tetap diam, wajah santai".
  final String headline;

  /// The movement the **server** asked for, in the server's own words. The app
  /// never invents one: a gesture written here would be a gesture the challenge
  /// did not draw.
  final String? instruction;

  /// A nudge for somebody who has been trying for a few seconds.
  final String? hint;

  /// How far the current movement has travelled, 0..1.
  ///
  /// Shown because a movement is scored against a threshold nobody can see:
  /// somebody turning fifteen degrees when twenty are wanted is doing the right
  /// thing and being told nothing, and the only correction available to them
  /// otherwise is to try harder at random.
  final double? progress;

  /// Which movement this is, and how many there are. Both come from the
  /// challenge — there is no invented progress here, and none is shown before
  /// the server has said how many steps it drew.
  final int? step;
  final int? totalSteps;

  /// False while the resting pose is still being measured.
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AttendanceCameraViewport.overlay;
    final Color accent = palette.brandAccent;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Same rule as the scan frame, and for the same reason: an oval sized
        // by a clamp whose bounds cross throws rather than shrinking.
        final double width = (constraints.maxWidth * 0.62).clamp(140.0, 260.0);
        final double height = math
            .min(width * 1.32, constraints.maxHeight - 140)
            .clamp(150.0, 360.0);

        final Rect oval = Rect.fromCenter(
          center: Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2 - AppSpacing.xxl,
          ),
          width: width,
          height: height,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ApertureScrim(
                  aperture: RRect.fromRectAndRadius(
                    oval,
                    Radius.elliptical(width / 2, height / 2),
                  ),
                  colour: palette.overlayScrim,
                ),
              ),
            ),
            Positioned.fromRect(
              rect: oval,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: settled ? accent : accent.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
              ),
            ),
            if (step != null && totalSteps != null && totalSteps! > 1)
              Positioned(
                left: 0,
                right: 0,
                top: oval.top - AppSpacing.xxl,
                child: _StepDots(
                  current: step!,
                  total: totalSteps!,
                  accent: accent,
                  palette: palette,
                ),
              ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: oval.bottom + AppSpacing.lg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Instruction(
                    icon: Icons.face_retouching_natural_rounded,
                    accent: accent,
                    title: instruction ?? headline,
                    subtitle: instruction == null ? hint : (hint ?? headline),
                    theme: theme,
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: 160,
                      child: ClipRRect(
                        borderRadius: AppRadii.pillAll,
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          minHeight: 4,
                          color: accent,
                          backgroundColor: palette.trackSubtle,
                          semanticsLabel: 'Kemajuan gerakan',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// `● ● ○` — which movement of how many.
///
/// Drawn only when the challenge actually named more than one. Nothing here
/// invents a step count, and nothing advances on a timer.
class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.current,
    required this.total,
    required this.accent,
    required this.palette,
  });

  final int current;
  final int total;
  final Color accent;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Langkah ${current + 1} dari $total',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < total; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              child: Container(
                width: index == current ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index <= current ? accent : palette.trackSubtle,
                  borderRadius: AppRadii.pillAll,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The caption block that sits under either guide.
class _Instruction extends StatelessWidget {
  const _Instruction({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final palette = AttendanceCameraViewport.overlay;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.snug,
        ),
        decoration: BoxDecoration(
          color: palette.overlayScrim,
          borderRadius: AppRadii.xlAll,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppIconSizes.sm, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.onOverlay,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle!,
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

/// Dims everything outside the aperture, and nothing inside it.
class _ApertureScrim extends CustomPainter {
  const _ApertureScrim({required this.aperture, required this.colour});

  final RRect aperture;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final Path outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(aperture),
    );

    canvas.drawPath(outside, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_ApertureScrim old) =>
      old.aperture != aperture || old.colour != colour;
}

class _Corners extends StatelessWidget {
  const _Corners({required this.colour, required this.busy});

  final Color colour;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppDurations.normal,
      opacity: busy ? 0.5 : 1,
      child: Stack(
        children: [
          _corner(Alignment.topLeft, top: true, left: true),
          _corner(Alignment.topRight, top: true, left: false),
          _corner(Alignment.bottomLeft, top: false, left: true),
          _corner(Alignment.bottomRight, top: false, left: false),
        ],
      ),
    );
  }

  Widget _corner(Alignment alignment, {required bool top, required bool left}) {
    const double length = 30;
    final BorderSide side = BorderSide(color: colour, width: 3);
    const Radius radius = Radius.circular(AppRadii.xxl);

    return Align(
      alignment: alignment,
      child: Container(
        width: length,
        height: length,
        decoration: BoxDecoration(
          border: Border(
            top: top ? side : BorderSide.none,
            bottom: top ? BorderSide.none : side,
            left: left ? side : BorderSide.none,
            right: left ? BorderSide.none : side,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? radius : Radius.zero,
            topRight: top && !left ? radius : Radius.zero,
            bottomLeft: !top && left ? radius : Radius.zero,
            bottomRight: !top && !left ? radius : Radius.zero,
          ),
        ),
      ),
    );
  }
}
