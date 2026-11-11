import 'dart:typed_data';

import 'package:esas/core/config/api_routes.dart';
import 'package:esas/core/network/api_client.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/permit/data/repositories/permit_repository.dart';
import 'package:esas/features/permit/data/services/permit_api_service.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/presentation/controllers/permit_show_controller.dart';
import 'package:esas/features/permit/presentation/views/permit_show_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements ApiClient {}

/// PRMT-03. A permit's attachment — a doctor's note, say — lives on the
/// tenant's private disk and is served only by `GET /permits/{id}/file`, to
/// the requester and the approvers. The app used to open
/// `{assetBaseUrl}/{file}` in a browser: no credential, no workspace, and an
/// AccessDenied for the approver who needed to read it.
void main() {
  late _Client client;
  late PermitRepository repository;

  setUp(() {
    client = _Client();
    repository = PermitRepository(
      api: PermitApiService(client),
      session: SessionRepository(
        tokenStorage: InMemoryTokenStorage(),
        localStorage: InMemoryLocalStorage(),
      ),
    );
  });

  test('the file comes from the authenticated endpoint', () async {
    when(() => client.getBytes(any())).thenAnswer(
      (_) async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]),
    );

    final attachment = await repository.attachment(
      permitId: 42,
      file: 'attendance/permits/surat-dokter.pdf',
    );

    verify(() => client.getBytes(ApiRoutes.permitFile(42))).called(1);
    expect(ApiRoutes.permitFile(42), '/permits/42/file');
    expect(attachment.filename, 'surat-dokter.pdf');
    expect(attachment.isImage, isFalse);
    expect(attachment.bytes, hasLength(5));
  });

  test('a photograph is recognised by its content, not its name', () async {
    when(() => client.getBytes(any())).thenAnswer(
      (_) async => Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x00]),
    );

    final attachment = await repository.attachment(
      permitId: 42,
      file: 'attendance/permits/upload',
    );

    expect(attachment.isImage, isTrue);
  });

  group('on the detail screen', () {
    setUpAll(() => initializeDateFormatting('id_ID'));
    tearDown(Get.reset);

    testWidgets('a photograph opens inside the app, from the session', (
      tester,
    ) async {
      Get.testMode = true;
      final repo = _Repo();
      when(() => repo.currentUserId).thenReturn(7);
      when(
        () => repo.attachment(permitId: 42, file: any(named: 'file')),
      ).thenAnswer(
        (_) async => PermitAttachment(
          filename: 'surat.jpg',
          bytes: Uint8List.fromList(_onePixelPng),
        ),
      );

      final controller = PermitShowController(repository: repo);
      Get.put<PermitShowController>(controller);
      controller.permitId.value = 42;
      controller.permit.value = Permit.fromJson({
        'id': 42,
        'permit_numbers': 'PRM-42',
        'start_date': '2026-11-12',
        'end_date': '2026-11-12',
        'file': 'attendance/permits/surat.jpg',
        'permit_type': {'id': 1, 'name': 'Sakit'},
      });
      controller.isLoading.value = false;

      await tester.pumpWidget(
        GetMaterialApp(
          locale: const Locale('id', 'ID'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('id', 'ID')],
          home: const PermitShowView(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('surat.jpg'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('surat.jpg'));
      await tester.pumpAndSettle();

      verify(
        () => repo.attachment(permitId: 42, file: 'attendance/permits/surat.jpg'),
      ).called(1);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}

class _Repo extends Mock implements PermitRepository {}

/// The smallest valid PNG: one transparent pixel.
const _onePixelPng = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
];
