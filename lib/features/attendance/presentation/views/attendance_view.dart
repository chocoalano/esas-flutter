import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/components/custom_bottom_navbar.dart';
import '../../../../core/ui/dialogs/app_dialogs.dart';
import '../../data/liveness/liveness_capture.dart';
import '../../data/liveness/liveness_diagnostics.dart';
import '../../data/repositories/attendance_repository.dart';
import '../controllers/attendance_controller.dart';
import '../widgets/attendance_camera_viewport.dart';
import '../widgets/attendance_direction_switch.dart';
import '../widgets/attendance_face_notice.dart';
import '../widgets/attendance_method_selector.dart';
import '../widgets/attendance_status_strip.dart';
import '../widgets/attendance_viewport_state.dart';

/// The attendance capture workspace.
///
/// ## What changed, and why it is structural rather than cosmetic
///
/// The screen this replaces was a full-bleed camera with a title, a scan frame
/// and six full-screen overlays floating on top of it. Three things followed
/// from that shape, and all three were the shape's fault:
///
/// 1. **A camera that could not open turned the whole page black.** The failure
///    read as a broken app rather than as a camera that could not start. Here
///    the darkness is one rounded viewport on an ordinary page — header,
///    method selector and bottom navigation stay exactly where they were.
/// 2. **There was one method.** The backend has offered two since
///    `attendance/face` shipped, and an employee whose face is enrolled had no
///    way to reach it. The selector is the whole answer, and which of its two
///    segments is usable comes from `attendance/context`.
/// 3. **Every camera failure said the same sentence.** "Periksa izin kamera"
///    was shown to somebody on a simulator with no camera at all, and "Coba
///    lagi" was the primary action for a permission only Settings can restore.
///
/// ## Reading order
///
/// Absensi → what I am about to do → which method → the camera → whether the
/// camera and location are ready. Five lines, top to bottom, and an employee
/// should be able to answer "what do I do now" from the first three without
/// reaching the camera at all.
class AttendanceView extends GetView<AttendanceController> {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        confirmExitApp(context);
      },
      child: Scaffold(
        // The page's own surface, not black. The camera is a panel on this
        // page; it is not the page.
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Short screens lose vertical air before they lose the viewport.
              // A 320×568 handset still shows selector, camera and status; what
              // it does not show is the breathing room a 430pt screen gets.
              final bool tight = constraints.maxHeight < 640;
              final double gap = tight ? AppSpacing.md : AppSpacing.lg;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  tight ? AppSpacing.xs : AppSpacing.sm,
                  AppSpacing.page,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Header(),
                    SizedBox(height: gap),
                    Obx(
                      () => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AttendanceMethodSelector(
                            active: controller.mode.value,
                            statusOf: controller.statusOf,
                            onSelect: controller.switchTo,
                          ),
                          AttendanceMethodNote(
                            status: controller.unavailableStatus,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),
                    Expanded(
                      child: AttendanceCameraViewport(
                        child: Obx(
                          () => AnimatedSwitcher(
                            // Keyed on the METHOD, not on the widget: a
                            // cross-fade when somebody switches QR ↔ wajah, and
                            // nothing at all when a state changes inside one
                            // method. Keying on the child itself would remount
                            // the camera preview on every rebuild, which is a
                            // black flash and a re-opened sensor.
                            duration: AppDurations.normal,
                            switchInCurve: AppMotion.standard,
                            switchOutCurve: AppMotion.exit,
                            child: KeyedSubtree(
                              key: ValueKey<AttendanceMethod>(
                                controller.mode.value,
                              ),
                              child: _viewport(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: tight ? AppSpacing.sm : AppSpacing.md),
                    Obx(() => AttendanceReadinessStrip(statuses: _statuses)),
                  ],
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: const CustomBottomNavBar(),
      ),
    );
  }

  // ── What fills the viewport ──────────────────────────────────────────────

  /// One decision, in priority order, and every branch is a typed state.
  ///
  /// The order is what stops two truths fighting for the same rectangle: a
  /// confirmed clock outranks everything, a request in flight outranks a stale
  /// refusal, and a refusal outranks the camera that produced it.
  Widget _viewport(BuildContext context) {
    final receipt = controller.receipt.value;

    if (receipt != null) return _success(receipt);

    if (controller.stage.value == CaptureStage.submitting) {
      return const AttendanceViewportState(
        icon: Icons.cloud_upload_outlined,
        tone: ViewportTone.brand,
        title: 'Memverifikasi absensi',
        // Never "berhasil" before the server has said so. The screen this
        // replaces confirmed from a `finally` that ran on every path.
        message: 'Menunggu jawaban server. Jangan tutup aplikasi.',
        busy: true,
      );
    }

    final refused = controller.refusal.value;

    if (refused != null && controller.stage.value == CaptureStage.refused) {
      return _refusal(refused);
    }

    if (controller.context.value?.canClock == false) {
      return AttendanceViewportState(
        icon: Icons.lock_outline_rounded,
        tone: ViewportTone.warning,
        title: 'Absensi belum diaktifkan',
        message:
            'Akun Anda belum diatur untuk mencatat kehadiran. Hubungi HR '
            'untuk mengaktifkannya.',
        secondaryLabel: 'Muat ulang',
        onSecondary: controller.loadContext,
      );
    }

    if (controller.locationStatus.value == LocationStatus.blocked) {
      return _locationBlocked();
    }

    return controller.mode.value == AttendanceMethod.qr
        ? _qrMode(context)
        : _faceMode(context);
  }

  // ── QR ───────────────────────────────────────────────────────────────────

  Widget _qrMode(BuildContext context) {
    final state = controller.scannerState.value;

    // A camera texture is only created where there is a camera to create it
    // for. A permission that has not been granted, or a device with no camera,
    // gets the explanation and nothing else — allocating a preview to sit
    // invisibly behind it would be a sensor held open for a panel nobody can
    // see through.
    const usable = <ScannerState>{
      ScannerState.idle,
      ScannerState.starting,
      ScannerState.ready,
      ScannerState.failed,
    };

    if (!usable.contains(state)) return _scannerState(state);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Mounted whenever QR is the active method, including while the camera
        // is still starting: `MobileScannerController.start()` refuses to run
        // without an attached widget, so a tree that waited for "ready" before
        // mounting it would never become ready.
        MobileScanner(
          controller: controller.scanner,
          onDetect: controller.onDetect,
          // Without this, a denied camera is a black rectangle with no word of
          // explanation. Reporting is deferred one frame: `errorBuilder` runs
          // during build, and changing state there rebuilds the tree that is
          // being built.
          errorBuilder: (context, error) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (controller.isClosed) return;
              controller.reportScannerFailure(error);
            });

            return const SizedBox.shrink();
          },
          placeholderBuilder: (context) => const SizedBox.shrink(),
        ),

        if (state == ScannerState.ready) _scanFrame() else _scannerState(state),

        if (state == ScannerState.ready) _torch(),
      ],
    );
  }

  Widget _scanFrame() {
    final busy = controller.stage.value == CaptureStage.detected;
    final hint = controller.refusal.value;

    return QrScanOverlay(
      busy: busy,
      // A code that was not an attendance code says so here, quietly, while the
      // camera keeps looking — not on a full-screen error with a button.
      hint: hint != null && hint.kind == RefusalKind.unrecognised
          ? hint.message
          : null,
    );
  }

  Widget _torch() {
    if (!controller.torchAvailable.value) return const SizedBox.shrink();

    final palette = AttendanceCameraViewport.overlay;
    final bool on = controller.torchOn.value;

    return Positioned(
      right: AppSpacing.md,
      top: AppSpacing.md,
      child: Semantics(
        button: true,
        label: on ? 'Matikan senter' : 'Nyalakan senter',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: controller.toggleTorch,
            borderRadius: AppRadii.pillAll,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.overlayScrim,
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? palette.brandAccent : palette.borderInteractive,
                ),
              ),
              child: Icon(
                on ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                size: AppIconSizes.xl,
                color: on ? palette.brandAccent : palette.onOverlay,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Why the QR camera is not showing a picture.
  ///
  /// Six causes, six sentences, and — the part that was wrong before — the right
  /// primary action for each. A permanent denial leads with Settings; a
  /// permission that has never been asked for leads with the request; a device
  /// with no camera is not offered either, because neither would do anything.
  Widget _scannerState(ScannerState state) {
    return switch (state) {
      ScannerState.idle ||
      ScannerState.starting => const AttendanceViewportState(
        icon: Icons.photo_camera_outlined,
        tone: ViewportTone.brand,
        title: 'Menyiapkan kamera',
        message: 'Sebentar lagi siap memindai.',
        busy: true,
      ),

      ScannerState.ready => const SizedBox.shrink(),

      ScannerState.permissionAskable => AttendanceViewportState(
        icon: Icons.photo_camera_outlined,
        tone: ViewportTone.brand,
        title: 'Izin kamera diperlukan',
        message:
            'Absensi QR memerlukan kamera untuk membaca kode. Berikan izin '
            'kamera untuk melanjutkan.',
        primaryLabel: 'Izinkan kamera',
        primaryIcon: Icons.photo_camera_rounded,
        onPrimary: controller.requestCameraPermission,
      ),

      // Settings first. "Coba lagi" as the primary action here is a button that
      // can only repeat itself: the OS will not show the prompt again.
      ScannerState.permissionPermanent => AttendanceViewportState(
        icon: Icons.lock_outline_rounded,
        tone: ViewportTone.warning,
        title: 'Izin kamera ditolak permanen',
        message:
            'Izin ini hanya bisa dipulihkan dari pengaturan aplikasi. Buka '
            'pengaturan, aktifkan kamera, lalu kembali ke sini.',
        primaryLabel: 'Buka pengaturan',
        primaryIcon: Icons.settings_outlined,
        onPrimary: controller.openCameraSettings,
        secondaryLabel: 'Saya sudah mengizinkan',
        onSecondary: controller.retryCamera,
      ),

      ScannerState.permissionRestricted => AttendanceViewportState(
        icon: Icons.policy_outlined,
        tone: ViewportTone.warning,
        title: 'Kamera dibatasi perangkat',
        message:
            'Kamera dibatasi oleh kebijakan perangkat ini, sehingga tidak '
            'dapat dipakai untuk absensi. Hubungi admin IT Anda.',
      ),

      // A simulator, or a handset whose camera is disabled. Blaming a
      // permission that has been granted is advice that cannot work — and this
      // is the state most often seen in testing.
      ScannerState.unsupported => AttendanceViewportState(
        icon: Icons.no_photography_outlined,
        tone: ViewportTone.warning,
        title: 'Kamera tidak tersedia',
        message:
            'Perangkat ini tidak memiliki kamera yang bisa dipakai untuk '
            'memindai QR.',
        secondaryLabel: 'Periksa lagi',
        onSecondary: controller.retryCamera,
      ),

      ScannerState.failed => AttendanceViewportState(
        icon: Icons.videocam_off_outlined,
        tone: ViewportTone.danger,
        title: 'Kamera gagal dibuka',
        message:
            'Kamera tidak dapat dijalankan saat ini. Tutup aplikasi lain yang '
            'sedang memakai kamera, lalu coba lagi.',
        primaryLabel: 'Coba lagi',
        primaryIcon: Icons.refresh_rounded,
        onPrimary: controller.retryCamera,
      ),
    };
  }

  // ── Face ─────────────────────────────────────────────────────────────────

  Widget _faceMode(BuildContext context) {
    final session = controller.capture.value;

    if (session == null) {
      final direction = controller.direction;

      return AttendanceViewportState(
        icon: Icons.face_retouching_natural_rounded,
        tone: ViewportTone.brand,
        title: direction == null
            ? 'Verifikasi wajah'
            : '${direction.label} dengan wajah',
        message:
            'Kamera depan akan terbuka dan Anda diminta melakukan beberapa '
            'gerakan singkat. Pastikan wajah terlihat jelas dan ruangan cukup '
            'terang.',
        primaryLabel: 'Mulai verifikasi',
        primaryIcon: Icons.play_arrow_rounded,
        onPrimary: () => _beginFace(context),
      );
    }

    return _faceSession(session);
  }

  /// Show the notice once per employee, then open the camera.
  ///
  /// The camera does not open until the notice has been shown at least once.
  /// This is information, not the consent itself — consent for biometric
  /// processing was recorded by HR against the enrolment, and the server will
  /// not report `face_enrolled` without it.
  Future<void> _beginFace(BuildContext context) async {
    if (!controller.faceNoticeSeen.value) {
      final read = await showFaceNotice(context);

      if (!read) return;

      await controller.acknowledgeFaceNotice();
    }

    await controller.startFace();
  }

  /// The live face session: preview underneath, guide and instructions above.
  ///
  /// Every observable here belongs to [LivenessCapture] and is watched
  /// directly, so a frame that moves a progress bar does not rebuild the page
  /// around it.
  Widget _faceSession(LivenessCapture session) {
    return ValueListenableBuilder<CameraController?>(
      valueListenable: session.preview,
      builder: (context, camera, _) {
        if (camera == null || !camera.value.isInitialized) {
          return AttendanceViewportState(
            icon: Icons.photo_camera_front_outlined,
            tone: ViewportTone.brand,
            title: 'Menyiapkan kamera depan',
            message: controller.faceMessage.value ?? 'Sebentar lagi siap.',
            busy: true,
            secondaryLabel: 'Batalkan',
            onSecondary: controller.cancelFace,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            _CoveringPreview(camera: camera),
            ValueListenableBuilder<LivenessPhase>(
              valueListenable: session.phase,
              builder: (context, phase, _) {
                return ValueListenableBuilder<int?>(
                  valueListenable: session.step,
                  builder: (context, step, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: session.progress,
                      builder: (context, progress, _) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: session.hint,
                          builder: (context, hint, _) {
                            return LivenessOverlay(
                              headline: _headlineFor(phase),
                              instruction: _instructionFor(session, step),
                              hint: hint,
                              progress: phase == LivenessPhase.performing
                                  ? progress
                                  : null,
                              step: step,
                              totalSteps: session.challenge.actions.length,
                              settled: phase != LivenessPhase.settling,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
            Positioned(
              right: AppSpacing.md,
              top: AppSpacing.md,
              child: _CancelButton(onTap: controller.cancelFace),
            ),
            // Physical-device QA only. `kDebugMode` is a compile-time constant,
            // so in release this branch and everything under it are removed by
            // the compiler — there is no flag that could turn it on in a shipped
            // build, because the code is not in one. It appears only while a
            // capture is actually running, which is why no golden shows it.
            if (LivenessDiagnosticsRecorder.enabled)
              Positioned(
                left: AppSpacing.md,
                bottom: AppSpacing.md,
                child: _DiagnosticsReadout(recorder: session.diagnostics),
              ),
          ],
        );
      },
    );
  }

  static String _headlineFor(LivenessPhase phase) => switch (phase) {
    LivenessPhase.opening => 'Menyiapkan kamera depan',
    LivenessPhase.settling => 'Tetap diam, wajah santai, menghadap kamera',
    LivenessPhase.performing => 'Ikuti gerakan yang diminta',
    LivenessPhase.composing => 'Bagus. Kembali menghadap kamera',
    LivenessPhase.capturing => 'Mengambil foto',
    LivenessPhase.idle => 'Verifikasi wajah',
  };

  /// The movement being asked for, **in the server's own words**.
  ///
  /// Never a sentence written here. The challenge catalogue lives on the server
  /// so a new movement never needs an app release to be explainable — and a
  /// gesture invented in the UI would be one the challenge did not draw.
  static String? _instructionFor(LivenessCapture session, int? step) {
    if (step == null || step >= session.challenge.actions.length) return null;

    final instruction = session.challenge.actions[step].instruction;

    return instruction.isEmpty ? null : instruction;
  }

  // ── Outcomes ─────────────────────────────────────────────────────────────

  Widget _success(AttendanceReceipt receipt) {
    return AttendanceViewportState(
      icon: Icons.check_rounded,
      tone: ViewportTone.success,
      title: '${receipt.direction.label} berhasil',
      message: receipt.message,
      // The server's own clock, and only when it sent one. The handset's time
      // is not a substitute on the one screen an employee screenshots as
      // evidence — a phone three minutes fast would print a time that disagrees
      // with the payslip.
      highlight: receipt.recordedAt,
      footnote: 'Tersimpan di server.',
      primaryLabel: 'Lihat riwayat',
      primaryIcon: Icons.arrow_forward_rounded,
      onPrimary: controller.finishReceipt,
    );
  }

  /// A refusal, drawn according to what kind of refusal it was.
  ///
  /// A code the server would not take is not the same event as a clock it would
  /// not write, and neither is the same as a face it could not match. The
  /// difference decides the icon, the tone and — mostly — whether there is
  /// anything to press.
  Widget _refusal(AttendanceRefusal refusal) {
    final (
      IconData icon,
      ViewportTone tone,
      String title,
    ) = switch (refusal.kind) {
      RefusalKind.unrecognised => (
        Icons.qr_code_scanner_rounded,
        ViewportTone.warning,
        'QR tidak dikenali',
      ),
      RefusalKind.codeRejected => (
        Icons.qr_code_rounded,
        ViewportTone.warning,
        'Kode tidak dapat dipakai',
      ),
      RefusalKind.clockRejected => (
        Icons.event_busy_outlined,
        ViewportTone.warning,
        'Absensi belum dapat diproses',
      ),
      RefusalKind.faceRejected => (
        Icons.face_retouching_off_rounded,
        ViewportTone.warning,
        'Verifikasi belum berhasil',
      ),
      RefusalKind.transient => (
        Icons.cloud_off_rounded,
        ViewportTone.danger,
        'Gagal menghubungi server',
      ),
      // No retry offered, deliberately. The row may already exist, and a second
      // attempt walks somebody into a duplicate the server will refuse.
      RefusalKind.unanswered => (
        Icons.help_outline_rounded,
        ViewportTone.warning,
        'Status absensi belum pasti',
      ),
    };

    final bool retryable = refusal.kind != RefusalKind.unanswered;

    return AttendanceViewportState(
      icon: icon,
      tone: tone,
      title: title,
      message: refusal.message,
      primaryLabel: retryable
          ? (controller.mode.value == AttendanceMethod.face
                ? 'Ulangi verifikasi'
                : 'Pindai lagi')
          : 'Lihat riwayat',
      primaryIcon: retryable
          ? Icons.refresh_rounded
          : Icons.arrow_forward_rounded,
      onPrimary: retryable ? controller.retryCapture : controller.openHistory,
      secondaryLabel: retryable ? 'Lihat riwayat' : null,
      onSecondary: retryable ? controller.openHistory : null,
    );
  }

  /// Why the handset may not clock from where it is.
  ///
  /// Six causes with six actions. They used to share one sentence and one pair
  /// of buttons — "Buka pengaturan lokasi" offered to somebody whose permission
  /// was permanently denied sends them to a page that cannot fix it, and
  /// "mendekatlah ke kantor" told to somebody whose GPS is off sends them
  /// walking for nothing.
  Widget _locationBlocked() {
    final block = controller.locationBlock.value;

    if (block == null) return const SizedBox.shrink();

    return switch (block) {
      LocationBlock.gpsOff => AttendanceViewportState(
        icon: Icons.gps_off_rounded,
        tone: ViewportTone.warning,
        title: 'GPS tidak aktif',
        message:
            'Perusahaan Anda memeriksa lokasi saat absensi. Aktifkan layanan '
            'lokasi perangkat, lalu coba lagi.',
        primaryLabel: 'Buka pengaturan lokasi',
        primaryIcon: Icons.settings_outlined,
        onPrimary: controller.openLocationSettings,
        secondaryLabel: 'Coba lagi',
        onSecondary: controller.revalidateLocation,
      ),

      LocationBlock.permissionDenied => AttendanceViewportState(
        icon: Icons.location_disabled_rounded,
        tone: ViewportTone.warning,
        title: 'Izin lokasi diperlukan',
        message:
            'Absensi memerlukan lokasi Anda untuk memastikan Anda berada di '
            'area kantor. Berikan izin lokasi, lalu coba lagi.',
        primaryLabel: 'Minta izin lokasi',
        primaryIcon: Icons.my_location_rounded,
        onPrimary: controller.revalidateLocation,
      ),

      LocationBlock.permissionPermanent => AttendanceViewportState(
        icon: Icons.lock_outline_rounded,
        tone: ViewportTone.danger,
        title: 'Izin lokasi ditolak permanen',
        message:
            'Izin ini hanya bisa dipulihkan dari pengaturan aplikasi. Buka '
            'pengaturan, aktifkan izin lokasi, lalu kembali ke sini.',
        primaryLabel: 'Buka pengaturan',
        primaryIcon: Icons.settings_outlined,
        onPrimary: controller.openApplicationSettings,
        secondaryLabel: 'Saya sudah mengizinkan',
        onSecondary: controller.revalidateLocation,
      ),

      LocationBlock.mocked => AttendanceViewportState(
        icon: Icons.wrong_location_rounded,
        tone: ViewportTone.danger,
        title: 'Lokasi palsu terdeteksi',
        message:
            'Perangkat ini sedang memakai aplikasi lokasi tiruan. Matikan '
            'aplikasi tersebut, lalu coba lagi.',
        primaryLabel: 'Coba lagi',
        primaryIcon: Icons.refresh_rounded,
        onPrimary: controller.revalidateLocation,
      ),

      LocationBlock.unreadable => AttendanceViewportState(
        icon: Icons.satellite_alt_outlined,
        tone: ViewportTone.warning,
        title: 'Lokasi belum terbaca',
        message:
            'Perangkat belum berhasil menentukan posisi Anda. Berdirilah di '
            'area yang lebih terbuka, lalu coba lagi.',
        primaryLabel: 'Coba lagi',
        primaryIcon: Icons.refresh_rounded,
        onPrimary: controller.revalidateLocation,
      ),

      LocationBlock.outOfRange => AttendanceViewportState(
        icon: Icons.location_off_rounded,
        tone: ViewportTone.warning,
        title: 'Di luar area absensi',
        message:
            '${_fenceSentence(controller.distanceMeters.value, controller.fenceRadius.value)} '
            'Mendekatlah ke area kantor, lalu coba lagi.',
        primaryLabel: 'Coba lagi',
        primaryIcon: Icons.refresh_rounded,
        onPrimary: controller.revalidateLocation,
      ),
    };
  }

  // ── Status strip ─────────────────────────────────────────────────────────

  /// Two facts at most, and only ones that are true.
  List<AttendanceReadiness> get _statuses {
    final statuses = <AttendanceReadiness>[
      AttendanceReadiness(
        label: switch (controller.scannerState.value) {
          ScannerState.ready => 'Kamera siap',
          ScannerState.starting || ScannerState.idle => 'Menyiapkan kamera',
          _ => 'Kamera bermasalah',
        },
        tone: switch (controller.scannerState.value) {
          ScannerState.ready => ReadinessTone.ready,
          ScannerState.starting || ScannerState.idle => ReadinessTone.pending,
          _ => ReadinessTone.blocked,
        },
        icon: Icons.photo_camera_outlined,
      ),
    ];

    // Only where the company actually checks. A chip saying "lokasi siap" in a
    // workspace with no geofence would be reporting on a permission the app
    // never asked for.
    switch (controller.locationStatus.value) {
      case LocationStatus.notRequired:
        break;
      case LocationStatus.checking:
        statuses.add(
          const AttendanceReadiness(
            label: 'Mencari lokasi',
            tone: ReadinessTone.pending,
            icon: Icons.my_location_rounded,
          ),
        );
      case LocationStatus.ready:
        statuses.add(
          const AttendanceReadiness(
            label: 'Lokasi siap',
            tone: ReadinessTone.ready,
            icon: Icons.my_location_rounded,
          ),
        );
      case LocationStatus.outsideFence:
        // Said, not enforced. The server has the last word and a wider radius
        // than this handset can see, so the capture stays available.
        statuses.add(
          const AttendanceReadiness(
            label: 'Tampaknya di luar area kerja',
            tone: ReadinessTone.pending,
            icon: Icons.my_location_rounded,
          ),
        );
      case LocationStatus.blocked:
        statuses.add(
          const AttendanceReadiness(
            label: 'Lokasi bermasalah',
            tone: ReadinessTone.blocked,
            icon: Icons.location_off_rounded,
          ),
        );
    }

    // Only when the screen is genuinely running blind. It changes what the
    // employee should expect — the header has no intent line, and a machine QR
    // cannot be redeemed without a direction — so it is worth one chip.
    if (controller.contextUnavailable.value) {
      statuses.add(
        const AttendanceReadiness(
          label: 'Status absensi belum dimuat',
          tone: ReadinessTone.blocked,
          icon: Icons.cloud_off_rounded,
        ),
      );
    }

    return statuses;
  }
}

/// "Anda 84 m dari titik absensi, batas 30 m."
///
/// Meter bulat, bukan dua desimal: `84,17 m` menjanjikan ketelitian yang tidak
/// dimiliki GPS ponsel mana pun, dan angka di belakang koma itu justru yang
/// membuat orang berpikir ada yang bisa ditawar.
String _fenceSentence(double? distance, double? radius) {
  if (distance == null) {
    return 'Anda berada di luar area absensi kantor.';
  }

  final parts = StringBuffer('Anda ${distance.round()} m dari titik absensi');

  if (radius != null) {
    parts.write(', batas ${radius.round()} m');
  }

  parts.write('.');

  return parts.toString();
}

/// Title, what is about to happen, and the way to the history.
///
/// One line and a subtitle rather than an `AppBar`: this screen's tallest
/// element should be the camera, and a 56pt bar of chrome above a viewport is
/// 56pt the viewport does not get.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final controller = Get.find<AttendanceController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The title row carries nothing that can contest it. The direction
        // pills sat here first and squeezed "Absensi" to one letter per line at
        // 320dp — a title is not a thing that should have to compete for width.
        Row(
          children: [
            Expanded(
              // A heading, and announced as one: the bottom bar carries the
              // word "Absensi" too, and a screen reader landing here should be
              // told which of the two it has reached.
              child: Semantics(
                header: true,
                child: Text('Absensi', style: theme.textTheme.titleLarge),
              ),
            ),
            IconButton(
              tooltip: 'Riwayat absensi',
              onPressed: controller.openHistory,
              icon: const Icon(Icons.history_rounded),
            ),
          ],
        ),
        // What is about to happen, and the choice of which. Sharing one row
        // costs no vertical space over the intent line alone, and the text
        // ellipsises rather than shoving the pills off the edge.
        Row(
          children: [
            Expanded(
              child: Obx(() {
                // Read from `next_presence` and the roster the server already
                // sent — never fetched for the sake of a subtitle, and simply
                // absent when the server has not said.
                final line = controller.intentLine;

                if (line == null) return const SizedBox.shrink();

                return Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                );
              }),
            ),
            const SizedBox(width: AppSpacing.sm),
            Obx(
              () => AttendanceDirectionSwitch(
                selected: controller.direction,
                expected: controller.expectedDirection,
                // Not while a request is in flight: it already carries a
                // direction, and the answer belongs to the attempt that asked.
                enabled:
                    controller.stage.value != CaptureStage.submitting &&
                    !controller.faceRunning &&
                    controller.context.value?.canClock != false,
                onChoose: controller.chooseDirection,
              ),
            ),
          ],
        ),
        // Only when the choice disagrees with the roster.
        Obx(
          () => AttendanceDirectionNote(
            show: controller.directionIsOverride,
            expected: controller.expectedDirection,
          ),
        ),
      ],
    );
  }
}

/// The front-camera preview, filling the viewport without distorting it.
class _CoveringPreview extends StatelessWidget {
  const _CoveringPreview({required this.camera});

  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // `CameraPreview` sizes itself to the sensor's aspect ratio; letting it
        // letterbox inside a rounded viewport leaves grey bars where the frame
        // should be.
        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxWidth * camera.value.aspectRatio,
            child: CameraPreview(camera),
          ),
        );
      },
    );
  }
}

/// The debug-only QA strip: frame rate, detector cost, face presence and size.
///
/// Never in a release build — see [LivenessDiagnosticsRecorder.enabled] — and
/// never carrying anything a face is made of. What a tester reads off it is
/// whether the pipeline is keeping up and whether the face is big enough at the
/// distance they are actually holding the phone.
class _DiagnosticsReadout extends StatelessWidget {
  const _DiagnosticsReadout({required this.recorder});

  final LivenessDiagnosticsRecorder recorder;

  @override
  Widget build(BuildContext context) {
    final palette = AttendanceCameraViewport.overlay;

    return ValueListenableBuilder<LivenessDiagnostics>(
      valueListenable: recorder.value,
      builder: (context, diagnostics, _) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: palette.overlayScrim,
            borderRadius: AppRadii.smAll,
          ),
          child: Text(
            diagnostics.toString(),
            style: AppTypography.dataSmall(color: palette.onOverlayMuted),
          ),
        );
      },
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AttendanceCameraViewport.overlay;

    return Semantics(
      button: true,
      label: 'Batalkan verifikasi wajah',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pillAll,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.overlayScrim,
              shape: BoxShape.circle,
              border: Border.all(color: palette.borderInteractive),
            ),
            child: Icon(
              Icons.close_rounded,
              size: AppIconSizes.xl,
              color: palette.onOverlay,
            ),
          ),
        ),
      ),
    );
  }
}
