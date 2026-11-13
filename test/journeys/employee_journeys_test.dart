import 'package:esas/core/ui/components/app_button.dart';
import 'package:esas/features/attendance/presentation/views/attendance_view.dart';
import 'package:esas/features/auth/data/models/device_status.dart';
import 'package:esas/features/auth/presentation/views/login_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'journey_harness.dart';

/// PO Putaran 7, Workstream E: the employee journeys, end to end.
///
/// AUTOMATED, NOT DEVICE UAT. Real screens and controllers, a faked HTTP layer
/// and a faked keystore channel (see `journey_harness.dart`). Every tap and
/// every text input is counted, and the counts are asserted: they are the
/// numbers to beat, and a change that adds a step fails here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  tearDownAll(() {
    for (final line in JourneyRecorder.results) {
      // ignore: avoid_print
      print(line);
    }
  });

  Finder button(String label) =>
      find.byWidgetPredicate((w) => w is AppButton && w.label == label);

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  final codeField = find.byKey(const ValueKey('enrollment-code-field'));

  Future<void> signIn(
    JourneyRecorder j, {
    String nip = journeyNip,
    String password = journeyPassword,
  }) async {
    j.screen('Login');
    expect(find.byType(LoginView), findsOneWidget);
    await j.type(field('NIP atau nama@perusahaan.com'), nip);
    await j.type(field('Masukkan kata sandi'), password);
    await j.tap(button('Masuk'));
  }

  Future<void> finish(WidgetTester tester, JourneyRecorder j) async {
    j.record();
    // Let the sign-in snackbar's own timer run out.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
  }

  testWidgets('J1 new employee: login → status → "Minta Kode dari HR" → code '
      '→ attendance ready', (tester) async {
    final world = JourneyWorld();
    await world.boot(tester);
    final j = JourneyRecorder('J1 enrolment', tester);

    await signIn(j);

    j.screen('Beranda');
    expect(find.text('Perangkat Absensi Belum Terdaftar'), findsOneWidget);
    expect(find.textContaining('Minta kode aktivasi ke HR'), findsOneWidget);
    await j.tap(find.text('Buka Absensi'));

    j.screen('Absensi: status perangkat');
    expect(find.text('Minta Kode dari HR'), findsOneWidget);
    await j.tap(button('Masukkan Kode Aktivasi'));

    j.screen('Kode aktivasi');
    expect(find.textContaining('berlaku 15 menit'), findsOneWidget);
    await j.type(codeField, 'abcde-12345');
    await j.tap(button('Daftarkan Perangkat'));

    expect(find.text('Perangkat Berhasil Didaftarkan'), findsOneWidget);
    await j.tap(button('Lanjut ke Absensi'));

    j.screen('Absensi: siap');
    expect(find.byType(AttendanceView), findsOneWidget);

    expect(world.server.enrollments, 1);
    expect(
      world.server.enrolledFingerprint,
      world.keystore.fingerprint(world.alias),
    );
    expect(j.taps, 5);
    expect(j.inputs, 3);
    await finish(tester, j);

    // Server vs UI (not counted in the journey): back on Beranda, the card
    // agrees with the server — no "belum terdaftar", no "verifikasi" left.
    await tester.tap(find.text('Beranda'));
    await settle(tester);
    expect(find.text('Perangkat Absensi Belum Terdaftar'), findsNothing);
    expect(
      find.text('Buka Absensi untuk memverifikasi perangkat'),
      findsNothing,
    );
    expect(
      world.server.device(world.session.token)['attendance_block'],
      isNull,
    );
  });

  testWidgets('J2 lost device: HR release → proof refused → recovery card → '
      'new code → enrolled', (tester) async {
    final world = JourneyWorld();
    final oldFingerprint = world.keystore.seed(world.alias);
    world.server.enrolledFingerprint = oldFingerprint;
    world.server.issueCode('FGHJK67890');
    await world.boot(tester);
    final j = JourneyRecorder('J2 lost device', tester);

    await signIn(j);

    j.screen('Beranda');
    expect(
      find.text('Buka Absensi untuk memverifikasi perangkat'),
      findsOneWidget,
    );

    // HR releases this phone while the employee is on Beranda.
    world.server.hrRelease();
    await j.tap(find.text('Buka Absensi'));

    j.screen('Absensi: pemulihan');
    j.failurePoint('proof refused (409 DEVICE_NOT_ENROLLED) after HR release');
    expect(find.text('Hubungi HR untuk Mengganti Perangkat'), findsOneWidget);
    await j.tap(button('Masukkan Kode Aktivasi'));

    j.screen('Kode aktivasi');
    await j.type(codeField, 'FGHJK67890');
    await j.tap(button('Daftarkan Perangkat'));
    expect(find.text('Perangkat Berhasil Didaftarkan'), findsOneWidget);
    await j.tap(button('Lanjut ke Absensi'));

    j.screen('Absensi: siap');
    expect(find.byType(AttendanceView), findsOneWidget);

    expect(world.keystore.generateCalls.last.replace, isTrue);
    expect(world.server.enrolledFingerprint, isNot(oldFingerprint));
    expect(
      world.server.enrolledFingerprint,
      world.keystore.fingerprint(world.alias),
    );
    expect(world.server.enrollments, 1);
    expect(j.taps, 5);
    expect(j.inputs, 3);
    await finish(tester, j);
  });

  testWidgets('J3 password reset: "Lupa kata sandi?" → submit → generic '
      'confirmation → back → login', (tester) async {
    final world = JourneyWorld(
      server: FakeEsasServer(proofRequired: false, enrollmentAvailable: false),
    );
    await world.boot(tester);
    final j = JourneyRecorder('J3 password reset', tester);

    j.screen('Login');
    await j.tap(find.text('Lupa kata sandi?'));

    j.screen('Lupa kata sandi');
    await j.type(
      field('Contoh: 12345678 atau nama@perusahaan.com'),
      journeyNip,
    );
    await j.tap(button('Kirim Instruksi Reset'));

    expect(find.text('Permintaan Terkirim'), findsOneWidget);
    expect(find.textContaining('Jika akun terdaftar'), findsOneWidget);
    await j.tap(button('Kembali ke Halaman Masuk'));

    // UX-C34: the NIP typed in the sheet is waiting in the sign-in form.
    // Before the fix this journey re-typed it (3 inputs, measured).
    j.screen('Login');
    final nipOnLogin = tester
        .widget<TextFormField>(field('NIP atau nama@perusahaan.com'))
        .controller
        ?.text;
    if ((nipOnLogin ?? '').isEmpty) {
      j.failurePoint('NIP typed in the reset sheet must be typed again');
    }
    expect(nipOnLogin, journeyNip);
    await j.type(field('Masukkan kata sandi'), journeyPassword);
    await j.tap(button('Masuk'));

    j.screen('Beranda');
    expect(find.text('Buka Absensi'), findsNothing);
    expect(j.taps, 4);
    expect(j.inputs, 2);
    await finish(tester, j);
  });

  testWidgets('J4 unsupported phone: login works → attendance refused with a '
      'clear instruction, before anyone fetches an HR code', (tester) async {
    final world = JourneyWorld();
    world.keystore.available = false;
    await world.boot(tester);
    final j = JourneyRecorder('J4 unsupported device', tester);

    await signIn(j);
    j.screen('Beranda');
    await j.tap(find.text('Buka Absensi'));

    j.screen('Absensi: ponsel tidak didukung');
    j.failurePoint('keystore unavailable');
    expect(
      find.text('Ponsel Belum Dapat Dipakai untuk Absensi'),
      findsOneWidget,
    );
    expect(find.textContaining('Hubungi HR'), findsWidgets);
    // Not sent to HR for a code this phone could never use.
    expect(button('Masukkan Kode Aktivasi'), findsNothing);

    expect(world.server.enrollments, 0);
    expect(world.server.usedCodes, isEmpty);
    expect(j.taps, 2);
    expect(j.inputs, 2);
    await finish(tester, j);
  });

  testWidgets('J5 network failure during enrolment: timeout → safe retry → one '
      'enrolment, same key', (tester) async {
    final world = JourneyWorld();
    world.server.dropNextEnrollBeforeApplying = true;
    await world.boot(tester);
    final j = JourneyRecorder('J5 network failure', tester);

    await signIn(j);
    j.screen('Beranda');
    await j.tap(find.text('Buka Absensi'));
    j.screen('Absensi: status perangkat');
    await j.tap(button('Masukkan Kode Aktivasi'));

    j.screen('Kode aktivasi');
    await j.type(codeField, journeyCode);
    await j.tap(button('Daftarkan Perangkat'));

    j.failurePoint('enrolment request timed out');
    expect(find.text('Tidak Ada Koneksi'), findsOneWidget);
    await j.tap(button('Coba Lagi'));

    expect(find.text('Perangkat Berhasil Didaftarkan'), findsOneWidget);
    await j.tap(button('Lanjut ke Absensi'));
    j.screen('Absensi: siap');
    expect(find.byType(AttendanceView), findsOneWidget);

    // One enrolment, and the retry sent the very same key.
    expect(world.server.enrollments, 1);
    expect(world.server.enrolChallengeKeys, hasLength(2));
    expect(
      world.server.enrolChallengeKeys.first,
      world.server.enrolChallengeKeys.last,
    );
    expect(world.keystore.generateCalls.map((c) => c.replace), [true, false]);
    expect(
      world.server.enrolledFingerprint,
      world.keystore.fingerprint(world.alias),
    );
    expect(j.taps, 6);
    expect(j.inputs, 3);
    await finish(tester, j);
  });

  testWidgets('J6 session expiry mid-flow: answer lost → 401 → "Silakan Masuk '
      'Kembali" → re-login → proof, no new code', (tester) async {
    final world = JourneyWorld();
    world.server.loseNextEnrollAnswerAfterApplying = true;
    await world.boot(tester);
    final j = JourneyRecorder('J6 session expiry', tester);

    await signIn(j);
    j.screen('Beranda');
    await j.tap(find.text('Buka Absensi'));
    j.screen('Absensi: status perangkat');
    await j.tap(button('Masukkan Kode Aktivasi'));

    j.screen('Kode aktivasi');
    await j.type(codeField, journeyCode);
    await j.tap(button('Daftarkan Perangkat'));

    j.failurePoint('enrolment answer lost; token already replaced → 401');
    j.screen('Login + dialog');
    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('Silakan Masuk Kembali'), findsOneWidget);
    await j.tap(find.text('Mengerti'));

    await signIn(j);
    j.screen('Beranda');
    expect(
      find.text('Buka Absensi untuk memverifikasi perangkat'),
      findsOneWidget,
    );
    await j.tap(find.text('Buka Absensi'));

    j.screen('Absensi: siap');
    expect(find.byType(AttendanceView), findsOneWidget);

    expect(world.server.enrollments, 1);
    expect(world.server.proofs, 1);
    expect(world.server.usedCodes, {journeyCode});
    expect(j.taps, 7);
    expect(j.inputs, 5);
    await finish(tester, j);
  });

  /// J1's enrolment, from Beranda to a ready Absensi.
  Future<void> enrolFromBeranda(JourneyRecorder j, String code) async {
    j.screen('Beranda');
    expect(find.text('Perangkat Absensi Belum Terdaftar'), findsOneWidget);
    await j.tap(find.text('Buka Absensi'));
    j.screen('Absensi: status perangkat');
    await j.tap(button('Masukkan Kode Aktivasi'));
    j.screen('Kode aktivasi');
    await j.type(codeField, code);
    await j.tap(button('Daftarkan Perangkat'));
    expect(find.text('Perangkat Berhasil Didaftarkan'), findsOneWidget);
    await j.tap(button('Lanjut ke Absensi'));
    j.screen('Absensi: siap');
    expect(find.byType(AttendanceView), findsOneWidget);
  }

  testWidgets('J7 cross-workspace: A enrolled in acme; B in globex — same '
      'numeric user id — is blocked; back in acme, A proves without a code', (
    tester,
  ) async {
    final acme = FakeEsasServer(workspace: 'acme');
    final globex = FakeEsasServer(
      workspace: 'globex',
      accounts: [
        FakeAccount(id: 7, nip: '30001', password: 'globex-123', name: 'Sari'),
      ],
    );
    final world = JourneyWorld(workspaces: {'acme': acme, 'globex': globex});
    await world.boot(tester);
    final j = JourneyRecorder('J7 cross-workspace', tester);
    final aliasA = world.aliasOf('acme', 7);
    final aliasB = world.aliasOf('globex', 7);

    // Workspace A: enrol.
    await signIn(j);
    await enrolFromBeranda(j, journeyCode);
    final tokenA = world.session.token;
    final deviceA = DeviceStatus.fromUser(world.session.user)!;
    expect(deviceA.proofValidUntil, isNotNull);
    expect(world.session.user!.raw['abilities'], contains('attendance'));

    // Switch to workspace B (a different account, the same id 7 there).
    await world.switchWorkspace(tester, 'globex');
    expect(world.session.token, isNull);
    expect(acme.knows(tokenA), isFalse, reason: 'old token revoked');

    await signIn(j, nip: '30001', password: 'globex-123');
    j.screen('Beranda (globex)');

    // Nothing carried over: token, proof window, ability, enrolment status.
    final userB = world.session.user!;
    final deviceB = DeviceStatus.fromUser(userB)!;
    expect(world.session.token, isNot(tokenA));
    expect(globex.knows(world.session.token), isTrue);
    expect(acme.knows(world.session.token), isFalse);
    expect(userB.raw['abilities'], isNot(contains('attendance')));
    expect(userB.canRecordAttendance, isFalse);
    expect(deviceB.keyEnrolled, isFalse);
    expect(deviceB.proofValidUntil, isNull);
    expect(deviceB.keyFingerprint, isNull);
    expect(aliasA, isNot(aliasB));

    // B's attendance is blocked, although A's key is on this phone.
    expect(find.text('Perangkat Absensi Belum Terdaftar'), findsOneWidget);
    await j.tap(find.text('Buka Absensi'));
    j.screen('Absensi: belum terdaftar (globex)');
    expect(find.byType(AttendanceView), findsNothing);
    expect(find.text('Perangkat Absensi Belum Terdaftar'), findsOneWidget);
    expect(world.keystore.keys.containsKey(aliasB), isFalse);
    // Says why a phone that holds a key is "not registered": per account.
    expect(find.textContaining('per akun'), findsOneWidget);
    expect(globex.proofs, 0);
    expect(globex.enrollments, 0);

    // Back to workspace A: proves with A's key, no code.
    await world.switchWorkspace(tester, 'acme');
    await signIn(j);
    j.screen('Beranda');
    expect(
      find.text('Buka Absensi untuk memverifikasi perangkat'),
      findsOneWidget,
    );
    await j.tap(find.text('Buka Absensi'));
    j.screen('Absensi: siap');
    expect(find.byType(AttendanceView), findsOneWidget);

    expect(acme.enrollments, 1);
    expect(acme.proofs, 1);
    expect(acme.usedCodes, {journeyCode});
    expect(world.keystore.keys.keys, [aliasA]);
    expect(j.taps, 9);
    expect(j.inputs, 7);
    await finish(tester, j);
  });

  testWidgets('J8 two accounts, one phone, one workspace: each has its own '
      'key; neither replaces the other', (tester) async {
    final acme = FakeEsasServer(
      accounts: [
        FakeAccount(id: 7, nip: journeyNip, password: journeyPassword),
        FakeAccount(id: 8, nip: '20240114', password: 'sari-12345'),
      ],
    )..issueCode('FGHJK67890', userId: 8);
    final world = JourneyWorld(server: acme);
    await world.boot(tester);
    final j = JourneyRecorder('J8 two accounts, one phone', tester);
    final alias7 = world.aliasOf(journeyWorkspace, 7);
    final alias8 = world.aliasOf(journeyWorkspace, 8);

    // Account 7 enrols.
    await signIn(j);
    await enrolFromBeranda(j, journeyCode);
    final fingerprint7 = world.keystore.fingerprint(alias7);

    // Account 8 on the same phone: not enrolled, blocked, and A's code is not
    // B's to use.
    await world.signOut(tester);
    await signIn(j, nip: '20240114', password: 'sari-12345');
    expect(world.session.user!.raw['abilities'], isNot(contains('attendance')));
    await enrolFromBeranda(j, 'FGHJK67890');

    expect(alias7, isNot(alias8));
    expect(world.keystore.fingerprint(alias7), fingerprint7);
    expect(acme.account(7).enrolledFingerprint, fingerprint7);
    expect(
      acme.account(8).enrolledFingerprint,
      world.keystore.fingerprint(alias8),
    );
    expect(fingerprint7, isNot(world.keystore.fingerprint(alias8)));

    // Account 7 again: its key is untouched, it proves without a code.
    await world.signOut(tester);
    await signIn(j);
    j.screen('Beranda');
    await j.tap(find.text('Buka Absensi'));
    j.screen('Absensi: siap');
    expect(find.byType(AttendanceView), findsOneWidget);

    expect(acme.enrollments, 2);
    expect(acme.proofs, 1);
    expect(world.keystore.generateCalls.map((c) => c.alias), [alias7, alias8]);
    expect(j.taps, 12);
    expect(j.inputs, 8);
    await finish(tester, j);
  });
}
