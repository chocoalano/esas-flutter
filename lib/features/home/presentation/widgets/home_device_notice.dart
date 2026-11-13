import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/components/app_badge.dart';
import '../../data/models/attendance_device_step.dart';

/// What Beranda's attendance card shows while attendance waits on the
/// attendance-device step (ADR-D, UX-C31).
///
/// Before this, a phone that WAS enrolled and only needed the automatic check
/// at the Absensi door read "Perangkat belum terdaftar" or "Izin absensi
/// terbatas" — both untrue, and the first sends people to HR for nothing.
/// Decided from `device.attendance_block` (see [attendanceDeviceStepOf]),
/// never from a sentence. Null means "not a device step": the card shows what
/// it always did.
AttendanceDeviceStep? homeDeviceStepOf(ApiException? error) =>
    error is AttendanceDeviceStepException ? error.step : null;

/// The badge: label, tone, icon.
(String, AppBadgeTone, IconData) homeDeviceBadgeFor(
  AttendanceDeviceStep step,
) => switch (step) {
  AttendanceDeviceStep.verifyAtAttendance => (
    'Perlu verifikasi',
    AppBadgeTone.neutral,
    Icons.verified_user_outlined,
  ),
  AttendanceDeviceStep.notEnrolled => (
    'Belum terdaftar',
    AppBadgeTone.neutral,
    Icons.phonelink_lock_rounded,
  ),
};

/// The title. The sentence under it is the exception's own message.
String homeDeviceTitleFor(AttendanceDeviceStep step) => switch (step) {
  AttendanceDeviceStep.verifyAtAttendance =>
    'Buka Absensi untuk memverifikasi perangkat',
  AttendanceDeviceStep.notEnrolled => 'Perangkat Absensi Belum Terdaftar',
};

/// The one action, the same for both: the Absensi tab is where the check runs
/// and where the code is entered.
const String homeDeviceActionLabel = 'Buka Absensi';
