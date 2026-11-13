import '../../../auth/data/models/auth_user.dart';
import '../../../auth/data/models/device_status.dart';
import '../repositories/home_repository.dart';

/// Which attendance-device step stands between this sign-in and attendance
/// (ADR-D), as `device.attendance_block` says.
enum AttendanceDeviceStep {
  /// The phone is enrolled; this sign-in has not been verified yet. Opening
  /// Absensi does it automatically.
  verifyAtAttendance,

  /// No active attendance key: a code from HR is needed.
  notEnrolled,
}

/// An [AttendanceAccessException] that knows WHY: the attendance-device step.
///
/// Still an [AttendanceAccessException], so everything that already treats
/// "attendance denied by the session" the same way (no clock button, no retry
/// loop) keeps doing so. Only the sentence changes: the generic one told an
/// enrolled phone that it was "belum terdaftar" (UX-C31).
class AttendanceDeviceStepException extends AttendanceAccessException {
  const AttendanceDeviceStepException({
    required super.isRegisteredDevice,
    required this.step,
  });

  final AttendanceDeviceStep step;

  @override
  String get message => switch (step) {
    AttendanceDeviceStep.verifyAtAttendance =>
      'Perangkat ini sudah terdaftar. Verifikasi berjalan otomatis saat Anda '
          'membuka Absensi.',
    AttendanceDeviceStep.notEnrolled =>
      'Minta kode aktivasi ke HR, lalu masukkan di menu Absensi. Fitur lain '
          'tetap bisa digunakan.',
  };
}

/// The device step for [user]'s session, or null when there is none — no
/// device object, the backend flag off, or a block that is not a device step.
/// Null keeps every existing sentence exactly as it was.
AttendanceDeviceStepException? attendanceDeviceStepOf(AuthUser? user) {
  final device = DeviceStatus.fromUser(user);

  if (device == null) return null;

  final AttendanceDeviceStep? step =
      device.attendanceBlock == AttendanceBlock.deviceProofRequired &&
          device.keyEnrolled
      ? AttendanceDeviceStep.verifyAtAttendance
      : device.attendanceBlock == AttendanceBlock.deviceNotEnrolled
      ? AttendanceDeviceStep.notEnrolled
      : null;

  if (step == null) return null;

  return AttendanceDeviceStepException(
    isRegisteredDevice: user?.isRegisteredDevice,
    step: step,
  );
}
