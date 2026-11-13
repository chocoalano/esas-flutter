import 'dart:async';

import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/auth/data/models/device_status.dart';
import 'package:esas/features/auth/data/repositories/device_proof_repository.dart';
import 'package:esas/features/auth/presentation/controllers/device_enrollment_controller.dart';
import 'package:esas/features/auth/presentation/routes/device_routes.dart';
import 'package:esas/features/auth/presentation/views/device_enrollment_view.dart';
import 'package:esas/core/ui/components/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements DeviceProofRepository {}

/// The enrolment screen, one state at a time. Every sentence is for an
/// employee; none of them shows a code or a fingerprint.
void main() {
  late _MockRepository repository;
  late int sessionNotices;

  const enrolled = DeviceStatus(
    proofRequired: true,
    enrollmentAvailable: true,
    keyEnrolled: true,
    keyFingerprint: 'IlfYwWq-JnSBK58YUV9Gn79JLLxxXt8uVrs1RWXf0UI',
  );

  setUp(() {
    Get.testMode = true;
    repository = _MockRepository();
    sessionNotices = 0;
    when(() => repository.current).thenReturn(null);
  });

  tearDown(Get.reset);

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: DeviceRoutes.enrollment,
        getPages: [
          GetPage(
            name: DeviceRoutes.enrollment,
            page: () => const DeviceEnrollmentView(),
            binding: BindingsBuilder(() {
              Get.put(
                DeviceEnrollmentController(
                  repository: repository,
                  onSessionEnded: () async => sessionNotices++,
                ),
              );
            }),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field() => find.byKey(const ValueKey('enrollment-code-field'));

  AppButton submitButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.byType(AppButton));

  Future<void> typeAndSubmit(WidgetTester tester, String code) async {
    await tester.enterText(field(), code);
    await tester.pump();
    await tester.ensureVisible(find.byType(AppButton));
    await tester.tap(find.byType(AppButton));
    await tester.pump();
  }

  void enrollAnswers(Future<DeviceStatus?> Function() answer) => when(
    () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
  ).thenAnswer((_) => answer());

  void enrollFails(DeviceProofFailure failure) => when(
    () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
  ).thenThrow(DeviceProofException(failure));

  testWidgets('asks for the code, formatted, and waits for all ten', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Masukkan Kode Aktivasi'), findsOneWidget);
    expect(find.textContaining('Minta Kode dari HR'), findsOneWidget);
    // The server cannot say "expired", so the screen says the lifetime first.
    expect(find.textContaining('berlaku 15 menit'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(field(), 'abcde1234');
    await tester.pump();

    expect(find.text('ABCDE-1234'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(field(), 'abcde12345');
    await tester.pump();

    expect(find.text('ABCDE-12345'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('shows that it is working while enrolling', (tester) async {
    final pending = Completer<DeviceStatus?>();
    enrollAnswers(() => pending.future);

    await pumpScreen(tester);
    await typeAndSubmit(tester, 'ABCDE12345');

    expect(find.text('Mendaftarkan perangkat…'), findsOneWidget);
    expect(submitButton(tester).busy, isTrue);

    pending.complete(enrolled);
    await tester.pumpAndSettle();
  });

  testWidgets('success says so, with a short device ID only', (tester) async {
    enrollAnswers(() async => enrolled);

    await pumpScreen(tester);
    await typeAndSubmit(tester, 'ABCDE12345');
    await tester.pumpAndSettle();

    expect(find.text('Perangkat Berhasil Didaftarkan'), findsOneWidget);
    expect(find.text('ID perangkat: …WXf0UI'), findsOneWidget);
    expect(find.textContaining('IlfYwWq'), findsNothing);
    expect(find.text('Lanjut ke Absensi'), findsOneWidget);
    verify(() => repository.enroll('ABCDE12345', freshKey: true)).called(1);
  });

  testWidgets('a refused code is "Kode Tidak Berlaku", and editing clears it', (
    tester,
  ) async {
    enrollFails(DeviceProofFailure.invalidCode);

    await pumpScreen(tester);
    await typeAndSubmit(tester, 'ABCDE12345');
    await tester.pumpAndSettle();

    expect(find.text('Kode Tidak Berlaku'), findsOneWidget);
    expect(find.textContaining('minta kode baru ke HR'), findsOneWidget);
    // A typo is answered like an expired code, so the copy names both.
    expect(find.textContaining('salah ketik'), findsOneWidget);

    await tester.enterText(field(), 'ABCDE1234');
    await tester.pump();

    expect(find.text('Kode Tidak Berlaku'), findsNothing);
  });

  testWidgets('offline offers a retry that reuses the key', (tester) async {
    enrollFails(DeviceProofFailure.offline);

    await pumpScreen(tester);
    await typeAndSubmit(tester, 'ABCDE12345');
    await tester.pumpAndSettle();

    expect(find.text('Tidak Ada Koneksi'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    enrollAnswers(() async => enrolled);
    await tester.ensureVisible(find.text('Coba Lagi'));
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Perangkat Berhasil Didaftarkan'), findsOneWidget);
    verify(() => repository.enroll('ABCDE12345', freshKey: false)).called(1);
  });

  testWidgets('a challenge that stayed expired after a refetch says so', (
    tester,
  ) async {
    enrollFails(DeviceProofFailure.challengeExpired);

    await pumpScreen(tester);
    await typeAndSubmit(tester, 'ABCDE12345');
    await tester.pumpAndSettle();

    expect(find.text('Waktu verifikasi habis. Coba lagi.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });

  testWidgets('a phone that cannot hold the key says so', (tester) async {
    enrollFails(DeviceProofFailure.keyUnavailable);

    await pumpScreen(tester);
    await typeAndSubmit(tester, 'ABCDE12345');
    await tester.pumpAndSettle();

    expect(
      find.text('Ponsel Belum Dapat Dipakai untuk Absensi'),
      findsOneWidget,
    );
    expect(find.text('Coba Lagi'), findsOneWidget);
  });

  testWidgets('a key the server will not accept sends the person to HR', (
    tester,
  ) async {
    enrollFails(DeviceProofFailure.proofInvalid);

    await pumpScreen(tester);
    await typeAndSubmit(tester, 'ABCDE12345');
    await tester.pumpAndSettle();

    expect(find.text('Hubungi HR untuk Mengganti Perangkat'), findsOneWidget);

    await tester.tap(find.text('Masukkan Kode Lain'));
    await tester.pumpAndSettle();

    expect(find.text('Masukkan Kode Aktivasi'), findsOneWidget);
    expect(find.text('ABCDE-12345'), findsNothing);
  });

  testWidgets('a double tap sends one enrolment', (tester) async {
    final pending = Completer<DeviceStatus?>();
    enrollAnswers(() => pending.future);

    await pumpScreen(tester);
    await tester.enterText(field(), 'ABCDE12345');
    await tester.pump();

    final controller = Get.find<DeviceEnrollmentController>();
    unawaited(controller.submit());
    unawaited(controller.submit());
    await tester.ensureVisible(find.byType(AppButton));
    await tester.tap(find.byType(AppButton));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(
      () => repository.enroll(any(), freshKey: any(named: 'freshKey')),
    ).called(1);

    pending.complete(enrolled);
    await tester.pumpAndSettle();
  });

  testWidgets('a lost answer that ended the session asks to sign in again, '
      'once', (tester) async {
    enrollFails(DeviceProofFailure.sessionEnded);

    await pumpScreen(tester);
    await typeAndSubmit(tester, 'ABCDE12345');
    await tester.pumpAndSettle();

    expect(find.text('Silakan Masuk Kembali'), findsOneWidget);
    expect(
      find.textContaining('tidak perlu meminta kode baru'),
      findsOneWidget,
    );
    expect(find.text('Masuk Kembali'), findsOneWidget);
    expect(sessionNotices, 1);
  });

  testWidgets('a retry after a refused code keeps the key it made', (
    tester,
  ) async {
    enrollFails(DeviceProofFailure.invalidCode);

    await pumpScreen(tester);
    await typeAndSubmit(tester, 'ABCDE12345');
    await tester.pumpAndSettle();
    await typeAndSubmit(tester, 'FGHJK12345');
    await tester.pumpAndSettle();

    verify(() => repository.enroll('ABCDE12345', freshKey: true)).called(1);
    verify(() => repository.enroll('FGHJK12345', freshKey: false)).called(1);
  });
}
