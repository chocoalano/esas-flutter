import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../attendance/presentation/routes/attendance_routes.dart';
import '../../data/models/device_status.dart';
import '../../data/models/enrollment_code.dart';
import '../../data/repositories/device_proof_repository.dart';
import '../widgets/device_session_notice.dart';

/// Where an enrolment attempt has got to. Each one is its own screen state.
enum EnrollmentStage {
  /// Typing the code.
  input,

  /// Key, challenge, signature, enrolment: in flight.
  submitting,

  /// "Kode Tidak Berlaku": wrong, expired, used or exhausted — the server
  /// deliberately does not say which, so neither does the screen.
  invalidCode,

  /// No connection. Nothing was enrolled; try again.
  offline,

  /// The phone cannot make or use a key.
  keyUnavailable,

  /// The key on this phone was not accepted: "Hubungi HR untuk Mengganti
  /// Perangkat". A retry makes a new key.
  recovery,

  /// Anything else, with its own sentence.
  failed,

  /// The token is gone and the app has signed out: "Silakan Masuk Kembali".
  /// If the enrolment did reach the server, signing in again is enough.
  sessionEnded,

  /// "Perangkat Berhasil Didaftarkan".
  success,
}

/// Enrol this phone for attendance with the code HR showed the employee.
class DeviceEnrollmentController extends GetxController {
  DeviceEnrollmentController({
    required DeviceProofRepository repository,
    Future<void> Function()? onSessionEnded,
  }) : _repository = repository,
       _onSessionEnded = onSessionEnded ?? showDeviceSessionEnded;

  final DeviceProofRepository _repository;

  /// Tells the person to sign in again, over whatever screen the 401 handler
  /// has opened. Injectable for tests.
  final Future<void> Function() _onSessionEnded;

  /// One enrolment at a time. [busy] is the same fact for the screen; this is
  /// the guard, set before the first `await`, so a double tap or the keyboard's
  /// "done" racing the button cannot send a second request.
  bool _submitting = false;

  final codeController = TextEditingController();

  /// The code as typed, normalised: up to ten Crockford symbols, no dash.
  final code = ''.obs;
  final stage = EnrollmentStage.input.obs;

  /// The sentence for [EnrollmentStage.failed].
  final failureMessage = RxnString();

  /// The device object after a successful enrolment.
  final enrolled = Rxn<DeviceStatus>();

  /// Whether this visit already made a key. A retry after a server refusal
  /// reuses it; a key the server would not accept is replaced.
  bool _keyMade = false;

  bool get codeComplete => EnrollmentCode.isValid(code.value);

  bool get busy => stage.value == EnrollmentStage.submitting;

  bool get canSubmit => codeComplete && !busy;

  @override
  void onClose() {
    codeController.dispose();
    super.onClose();
  }

  void onCodeChanged(String text) {
    code.value = EnrollmentCode.sanitize(text);

    // Editing the code is the answer to a refusal of the code.
    if (stage.value == EnrollmentStage.invalidCode ||
        stage.value == EnrollmentStage.failed ||
        stage.value == EnrollmentStage.offline) {
      stage.value = EnrollmentStage.input;
      failureMessage.value = null;
    }
  }

  Future<void> submit() async {
    if (_submitting || !canSubmit) return;

    _submitting = true;
    stage.value = EnrollmentStage.submitting;
    failureMessage.value = null;

    try {
      final device = await _repository.enroll(code.value, freshKey: !_keyMade);

      _keyMade = true;
      enrolled.value = device ?? _repository.current;
      stage.value = EnrollmentStage.success;
    } on DeviceProofException catch (error) {
      _settleFailure(error.failure);
    } finally {
      _submitting = false;
    }
  }

  void _settleFailure(DeviceProofFailure failure) {
    switch (failure) {
      case DeviceProofFailure.keyUnavailable || DeviceProofFailure.keyMissing:
        // Nothing usable was made.
        _keyMade = false;
        stage.value = EnrollmentStage.keyUnavailable;
      case DeviceProofFailure.keyUnsupported:
        _keyMade = false;
        stage.value = EnrollmentStage.keyUnavailable;
      case DeviceProofFailure.proofInvalid:
        _keyMade = false;
        stage.value = EnrollmentStage.recovery;
      case DeviceProofFailure.invalidCode:
        _keyMade = true;
        stage.value = EnrollmentStage.invalidCode;
      case DeviceProofFailure.offline:
        _keyMade = true;
        stage.value = EnrollmentStage.offline;
      case DeviceProofFailure.challengeExpired:
        _keyMade = true;
        _fail('Waktu verifikasi habis. Coba lagi.');
      case DeviceProofFailure.rateLimited:
        _keyMade = true;
        _fail('Terlalu banyak percobaan. Tunggu sebentar, lalu coba lagi.');
      case DeviceProofFailure.disabled:
        _fail(
          'Pendaftaran perangkat belum dibuka oleh perusahaan. Hubungi HR.',
        );
      case DeviceProofFailure.sessionEnded:
        // The key stays: if the enrolment landed, the server holds it, and
        // the next sign-in proves with it instead of asking HR again.
        _keyMade = true;
        stage.value = EnrollmentStage.sessionEnded;
        unawaited(_onSessionEnded());
      case DeviceProofFailure.notEnrolled || DeviceProofFailure.failed:
        _keyMade = true;
        _fail(
          'Perangkat belum dapat didaftarkan. Coba lagi beberapa saat lagi.',
        );
    }
  }

  /// After "Hubungi HR untuk Mengganti Perangkat": a new code from HR, typed
  /// into an empty field, enrolled with a new key.
  void startOver() {
    codeController.clear();
    code.value = '';
    failureMessage.value = null;
    _keyMade = false;
    stage.value = EnrollmentStage.input;
  }

  void _fail(String message) {
    failureMessage.value = message;
    stage.value = EnrollmentStage.failed;
  }

  /// Back to attendance, which reads the new device state on return.
  void finish() {
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back<bool>(result: stage.value == EnrollmentStage.success);
      return;
    }

    Get.offAllNamed(AttendanceRoutes.attendance);
  }
}
