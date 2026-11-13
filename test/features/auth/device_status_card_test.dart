import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/data/models/device_status.dart';
import 'package:esas/features/auth/data/repositories/device_proof_gate.dart';
import 'package:esas/features/auth/data/repositories/device_proof_repository.dart';
import 'package:esas/features/auth/presentation/widgets/device_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether attendance is ready on this phone and what to do, driven by
/// `attendance_block` through the gate's decision.
void main() {
  const enrollmentOpen = DeviceStatus(
    proofRequired: true,
    enrollmentAvailable: true,
    attendanceBlock: AttendanceBlock.deviceNotEnrolled,
  );

  Future<void> pumpCard(WidgetTester tester, DeviceStatusCard card) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: card)),
      ),
    );
  }

  testWidgets('not enrolled: the two steps and the code entry', (tester) async {
    var opened = 0;

    await pumpCard(
      tester,
      DeviceStatusCard(
        status: DeviceGateStatus.notEnrolled,
        device: enrollmentOpen,
        onEnterCode: () => opened++,
        onRetry: () {},
      ),
    );

    expect(find.text('Perangkat Absensi Belum Terdaftar'), findsOneWidget);
    expect(find.text('Minta Kode dari HR'), findsOneWidget);
    // The step and the button share the words.
    expect(find.text('Masukkan Kode Aktivasi'), findsNWidgets(2));

    await tester.ensureVisible(find.text('Masukkan Kode Aktivasi').last);
    await tester.tap(find.text('Masukkan Kode Aktivasi').last);

    expect(opened, 1);
  });

  testWidgets('not enrolled while enrolment is closed: HR only', (
    tester,
  ) async {
    await pumpCard(
      tester,
      DeviceStatusCard(
        status: DeviceGateStatus.notEnrolled,
        device: const DeviceStatus(proofRequired: true),
        onEnterCode: () {},
      ),
    );

    // Only the step mentions the code; there is no button to enter one.
    expect(find.text('Masukkan Kode Aktivasi'), findsOneWidget);
    expect(find.textContaining('Hubungi HR'), findsOneWidget);
  });

  testWidgets('recovery sends the person to HR and still takes a new code', (
    tester,
  ) async {
    var retried = 0;

    await pumpCard(
      tester,
      DeviceStatusCard(
        status: DeviceGateStatus.recovery,
        device: enrollmentOpen,
        onEnterCode: () {},
        onRetry: () => retried++,
      ),
    );

    expect(find.text('Hubungi HR untuk Mengganti Perangkat'), findsOneWidget);
    expect(find.text('Masukkan Kode Aktivasi'), findsOneWidget);

    await tester.ensureVisible(find.text('Periksa Lagi'));
    await tester.tap(find.text('Periksa Lagi'));

    expect(retried, 1);
  });

  testWidgets('an open enrolment offer can be passed over', (tester) async {
    var continued = 0;

    await pumpCard(
      tester,
      DeviceStatusCard(
        status: DeviceGateStatus.offerEnrollment,
        device: const DeviceStatus(enrollmentAvailable: true),
        onEnterCode: () {},
        onContinue: () => continued++,
      ),
    );

    expect(find.text('Perangkat Absensi Belum Terdaftar'), findsOneWidget);

    await tester.ensureVisible(find.text('Lanjut ke Absensi'));
    await tester.tap(find.text('Lanjut ke Absensi'));

    expect(continued, 1);
  });

  testWidgets('ready shows the short device ID, never the fingerprint', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const DeviceStatusCard(
        status: DeviceGateStatus.ready,
        device: DeviceStatus(
          proofRequired: true,
          keyEnrolled: true,
          keyFingerprint: 'IlfYwWq-JnSBK58YUV9Gn79JLLxxXt8uVrs1RWXf0UI',
        ),
      ),
    );

    expect(find.text('Absensi Siap di Perangkat Ini'), findsOneWidget);
    expect(find.text('ID perangkat: …WXf0UI'), findsOneWidget);
    expect(find.textContaining('IlfYwWq'), findsNothing);
  });

  testWidgets('busy shows progress and no buttons', (tester) async {
    await pumpCard(
      tester,
      DeviceStatusCard(
        status: DeviceGateStatus.needsProof,
        busy: true,
        onRetry: () {},
      ),
    );

    expect(find.text('Memeriksa Perangkat'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Coba Lagi'), findsNothing);
  });

  testWidgets('offline and failures offer a retry', (tester) async {
    var retried = 0;

    await pumpCard(
      tester,
      DeviceStatusCard(
        status: DeviceGateStatus.offline,
        onRetry: () => retried++,
      ),
    );

    expect(find.text('Tidak Ada Koneksi'), findsOneWidget);

    await tester.tap(find.text('Coba Lagi'));
    expect(retried, 1);

    await pumpCard(
      tester,
      DeviceStatusCard(
        status: DeviceGateStatus.failed,
        failure: DeviceProofFailure.failed,
        onRetry: () {},
      ),
    );

    // A 429 has its own "sedang ramai" state now (Putaran 9); this is the
    // generic failure, which still names HR if it keeps happening.
    expect(find.text('Perangkat Belum Dapat Diverifikasi'), findsOneWidget);
    expect(find.textContaining('hubungi HR'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });

  testWidgets('a phone that can never hold the key is sent to HR for another '
      'way to clock, not to "Coba Lagi"', (tester) async {
    await pumpCard(
      tester,
      DeviceStatusCard(
        status: DeviceGateStatus.keyUnavailable,
        failure: DeviceProofFailure.keyUnsupported,
        device: enrollmentOpen,
        onEnterCode: () {},
        onRetry: () {},
      ),
    );

    expect(
      find.text('Ponsel Belum Dapat Dipakai untuk Absensi'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Hubungi HR untuk cara absensi lain'),
      findsOneWidget,
    );
    expect(find.textContaining('Fitur lain'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsNothing);
    expect(find.text('Masukkan Kode Aktivasi'), findsNothing);
  });

  testWidgets('busy: says so, and the retry waits as long as the server '
      'asked', (tester) async {
    var retried = 0;

    await pumpCard(
      tester,
      DeviceStatusCard(
        status: DeviceGateStatus.failed,
        failure: DeviceProofFailure.rateLimited,
        retryIn: const Duration(seconds: 20),
        onRetry: () => retried++,
      ),
    );

    expect(find.text('Pemeriksaan Perangkat Sedang Ramai'), findsOneWidget);
    expect(find.textContaining('jam masuk'), findsOneWidget);
    final wait = find.text('Coba lagi dalam 20 detik');
    expect(wait, findsOneWidget);
    await tester.tap(wait, warnIfMissed: false);
    expect(retried, 0);
  });

  testWidgets('limiter down: temporary, and when to call HR', (tester) async {
    await pumpCard(
      tester,
      DeviceStatusCard(
        status: DeviceGateStatus.failed,
        failure: DeviceProofFailure.limiterUnavailable,
        onRetry: () {},
      ),
    );

    expect(find.text('Pemeriksaan Perangkat Belum Tersedia'), findsOneWidget);
    expect(find.textContaining('hubungi HR'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });

  testWidgets('a phone without a usable keystore', (tester) async {
    await pumpCard(
      tester,
      DeviceStatusCard(status: DeviceGateStatus.keyUnavailable, onRetry: () {}),
    );

    expect(
      find.text('Ponsel Belum Dapat Dipakai untuk Absensi'),
      findsOneWidget,
    );
    expect(find.text('Coba Lagi'), findsOneWidget);
  });
}
