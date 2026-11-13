import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/ui/components/custom_bottom_navbar.dart';
import '../../../../core/ui/controllers/bottom_nav_controller.dart';
import '../../../../core/ui/dialogs/app_dialogs.dart';
import '../../../auth/data/models/device_status.dart';
import '../../../auth/data/repositories/device_proof_gate.dart';
import '../../../auth/presentation/bindings/device_bindings.dart';
import '../../../auth/presentation/routes/device_routes.dart';
import '../../../auth/presentation/widgets/device_session_notice.dart';
import '../../../auth/presentation/widgets/device_status_card.dart';
import '../../data/repositories/attendance_repository.dart';
import '../controllers/attendance_controller.dart';
import '../views/attendance_view.dart';
import '../routes/attendance_routes.dart';

/// The route guard on `/attendance` (ADR-D §9 option c).
///
/// Wraps the attendance screen — and only that screen; `/attendance/list`
/// inherits this middleware as a child route and is returned untouched — in
/// [AttendanceDeviceGate]. Every way in (the bottom bar, the Beranda tiles,
/// the service grid, a deep link) is a named route, so this is the one entry.
///
/// Nothing here touches Face or liveness: the gate decides whether the
/// attendance screen is built at all, before its controller exists.
class AttendanceDeviceGateMiddleware extends GetMiddleware {
  @override
  Widget onPageBuilt(Widget page) =>
      page is AttendanceView ? AttendanceDeviceGate(child: page) : page;
}

/// Shows [child] (the attendance screen) once this phone may clock, and the
/// device status card until then.
///
/// Without a device object from the server, or with the backend's flag off,
/// [child] is returned on the very first frame with no request made: the
/// screen looks and behaves exactly as it did before ADR-D.
///
/// While [child] is shown, a 403 `DEVICE_PROOF_REQUIRED` from an attendance
/// call (read from the screen's refusal, by its `code`) is answered with one
/// automatic re-proof, and the refusal is replaced with a sentence asking the
/// person to try again.
class AttendanceDeviceGate extends StatefulWidget {
  const AttendanceDeviceGate({
    super.key,
    required this.child,
    this.gate,
    this.openEnrollment,
    this.onSessionEnded,
  });

  final Widget child;

  /// For tests; the session-wide gate otherwise.
  final DeviceProofGate? gate;

  /// For tests; opens [DeviceRoutes.enrollment] otherwise.
  final Future<Object?> Function()? openEnrollment;

  /// For tests; [showDeviceSessionEnded] otherwise.
  final Future<void> Function()? onSessionEnded;

  @override
  State<AttendanceDeviceGate> createState() => _AttendanceDeviceGateState();
}

class _AttendanceDeviceGateState extends State<AttendanceDeviceGate> {
  static const _reproving = 'device_reproving';

  DeviceProofGate? _gate;
  DeviceGateDecision _decision = const DeviceGateDecision(
    DeviceGateStatus.ready,
  );
  bool _busy = false;
  bool _opening = false;
  bool _watching = false;
  Worker? _refusalWorker;
  Worker? _receiptWorker;

  @override
  void initState() {
    super.initState();

    final gate = _gate = widget.gate ?? findDeviceProofGate();

    if (gate == null) return;

    final initial = gate.evaluate();

    if (initial.status == DeviceGateStatus.needsProof) {
      _decision = initial;
      _busy = true;
      unawaited(_settle(gate.ensureReady()));
      return;
    }

    // A new visit earns a new automatic re-proof.
    gate.resetRetryBudget();
    _decision = initial;

    // Shown at once; corrected if this phone could never use a code. Only for
    // the decisions that lead to a code — the flag-off path asks nothing.
    if (initial.status == DeviceGateStatus.notEnrolled ||
        initial.status == DeviceGateStatus.recovery ||
        initial.status == DeviceGateStatus.offerEnrollment) {
      unawaited(_confirmKeystore(gate, initial));
    }
  }

  Future<void> _confirmKeystore(
    DeviceProofGate gate,
    DeviceGateDecision initial,
  ) async {
    final confirmed = await gate.confirmKeystore(initial);

    if (!mounted || _busy || identical(confirmed, initial)) return;
    if (_decision.status != initial.status) return;

    setState(() => _decision = confirmed);
  }

  @override
  void dispose() {
    _refusalWorker?.dispose();
    _receiptWorker?.dispose();
    super.dispose();
  }

  Future<void> _settle(Future<DeviceGateDecision> step) async {
    final decision = await step;

    // Told whether or not this screen survived: the 401 handler has usually
    // replaced it with the sign-in screen already.
    _noteSessionEnded(decision);

    if (!mounted) return;

    setState(() {
      _busy = false;
      _decision = decision;
    });
  }

  void _noteSessionEnded(DeviceGateDecision decision) {
    if (decision.status != DeviceGateStatus.sessionEnded) return;

    unawaited((widget.onSessionEnded ?? showDeviceSessionEnded)());
  }

  /// One check at a time: a second tap while one runs does nothing.
  void _run(Future<DeviceGateDecision> Function() step) {
    if (_busy) return;

    setState(() => _busy = true);
    unawaited(_settle(step()));
  }

  /// Opens the code screen once, however many times the button is tapped.
  Future<void> _enterCode() async {
    if (_opening) return;
    _opening = true;

    try {
      final open =
          widget.openEnrollment ??
          () async => await Get.toNamed<Object?>(DeviceRoutes.enrollment);

      await open();
    } finally {
      _opening = false;
    }

    final gate = _gate;

    if (!mounted || gate == null) return;

    _run(gate.ensureReady);
  }

  void _retry() {
    final gate = _gate;

    if (gate != null) _run(gate.refresh);
  }

  void _continue() {
    _gate?.deferEnrollment();
    setState(() {
      _decision = DeviceGateDecision(
        DeviceGateStatus.ready,
        device: _decision.device,
      );
    });
  }

  // ── The 403 path ─────────────────────────────────────────────────────────

  /// Read the attendance screen's refusals once it exists. The controller is
  /// the route's, made by `AttendanceBinding` when the screen first builds.
  void _watchAttendance() {
    if (_watching || _gate == null) return;
    _watching = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !Get.isRegistered<AttendanceController>()) return;

      final controller = Get.find<AttendanceController>();

      _refusalWorker = ever<AttendanceRefusal?>(
        controller.refusal,
        (refusal) => _onRefusal(controller, refusal),
      );
      _receiptWorker = ever<AttendanceReceipt?>(controller.receipt, (receipt) {
        if (receipt != null) _gate?.resetRetryBudget();
      });
    });
  }

  Future<void> _onRefusal(
    AttendanceController controller,
    AttendanceRefusal? refusal,
  ) async {
    final gate = _gate;

    if (gate == null || refusal?.code != DeviceErrorCodes.proofRequired) {
      return;
    }

    // Not "Hubungi HR": the classifier has never heard of this code, and the
    // answer is a fresh proof, not a person.
    controller.refusal.value = const AttendanceRefusal(
      kind: RefusalKind.clockRejected,
      message: 'Memverifikasi ulang perangkat. Tunggu sebentar.',
      code: _reproving,
    );

    final decision = await gate.reproveAfterRefusal();

    _noteSessionEnded(decision);

    if (!mounted) return;

    switch (decision.status) {
      case DeviceGateStatus.ready:
        _replace(
          controller,
          const AttendanceRefusal(
            kind: RefusalKind.clockRejected,
            message: 'Perangkat sudah diverifikasi ulang. Silakan coba lagi.',
            code: 'device_reproved',
          ),
        );
      case DeviceGateStatus.notEnrolled ||
          DeviceGateStatus.recovery ||
          DeviceGateStatus.keyUnavailable ||
          DeviceGateStatus.sessionEnded:
        setState(() => _decision = decision);
      case DeviceGateStatus.offline:
        _replace(
          controller,
          const AttendanceRefusal(
            kind: RefusalKind.transient,
            message:
                'Perangkat belum dapat diverifikasi. Periksa koneksi '
                'internet, lalu coba lagi.',
            code: 'device_proof_offline',
          ),
        );
      case DeviceGateStatus.failed ||
          DeviceGateStatus.needsProof ||
          DeviceGateStatus.offerEnrollment:
        _replace(
          controller,
          const AttendanceRefusal(
            kind: RefusalKind.clockRejected,
            message:
                'Perangkat belum dapat diverifikasi untuk absensi. Coba lagi '
                'beberapa saat lagi. Bila berulang, hubungi HR.',
            code: 'device_proof_failed',
          ),
        );
    }
  }

  /// Only while the interim sentence is still on screen. If the person has
  /// already pressed retry, the camera is back and there is nothing to replace.
  void _replace(AttendanceController controller, AttendanceRefusal next) {
    if (controller.refusal.value?.code != _reproving) return;

    controller.refusal.value = next;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_decision.isReady && !_busy) {
      _watchAttendance();
      return widget.child;
    }

    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        confirmExitApp(context);
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.bottomSafe,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('Absensi', style: theme.textTheme.titleLarge),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Riwayat absensi',
                    onPressed: () => Get.offAllNamed(AttendanceRoutes.list),
                    icon: const Icon(Icons.history_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              DeviceStatusCard(
                status: _busy ? DeviceGateStatus.needsProof : _decision.status,
                device: _decision.device ?? _gate?.device,
                failure: _decision.failure,
                busy: _busy,
                onEnterCode: _enterCode,
                onRetry: _retry,
                onContinue: _continue,
              ),
            ],
          ),
        ),
        bottomNavigationBar: Get.isRegistered<BottomNavController>()
            ? const CustomBottomNavBar()
            : null,
      ),
    );
  }
}
