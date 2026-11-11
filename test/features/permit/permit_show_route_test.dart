import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/data/repositories/permit_repository.dart';
import 'package:esas/features/permit/presentation/routes/permit_pages.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements PermitRepository {}

Permit permit(int id) => Permit.fromJson({
  'id': id,
  'permit_numbers': 'PRM-$id',
  'start_date': '2026-11-12',
  'end_date': '2026-11-12',
  'permit_type': {'id': 1, 'name': 'Cuti'},
});

/// PRMT-09. A notification for permit B, tapped while permit A is open, pushes
/// a second `/permit/show`. `lazyPut` of a type that is already registered is a
/// no-op, so the new screen used to be handed A's controller — showing A, and
/// approving A.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  tearDown(Get.reset);

  testWidgets('a second detail screen shows, and acts on, its own permit', (
    tester,
  ) async {
    Get.testMode = true;
    final repo = _Repo();
    when(() => repo.currentUserId).thenReturn(7);
    when(() => repo.detail(any())).thenAnswer(
      (invocation) async => permit(invocation.positionalArguments.single as int),
    );
    Get.put<PermitRepository>(repo);

    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('id', 'ID'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('id', 'ID')],
        initialRoute: '/start',
        getPages: [
          GetPage(name: '/start', page: () => const Scaffold()),
          ...PermitPages.pages,
        ],
      ),
    );

    Get.toNamed(PermitRoutes.show, arguments: {'id': 1});
    await tester.pumpAndSettle();
    expect(find.text('PRM-1'), findsOneWidget);

    // What a notification tap does.
    Get.toNamed(
      PermitRoutes.show,
      arguments: {'id': 2},
      preventDuplicates: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('PRM-2'), findsOneWidget);
    verify(() => repo.detail(2)).called(1);

    // And going back finds A again, untouched.
    Get.back();
    await tester.pumpAndSettle();
    expect(find.text('PRM-1'), findsOneWidget);
  });

  // PRMT-10. Back from the detail always replaced the whole stack with the
  // list — so from the home screen it never went home, and from a
  // notification (no type known) it landed on an empty list.
  group('going back', () {
    late _Repo repo;

    Future<void> pumpApp(WidgetTester tester) async {
      Get.testMode = true;
      repo = _Repo();
      when(() => repo.currentUserId).thenReturn(7);
      when(() => repo.detail(any())).thenAnswer(
        (invocation) async =>
            permit(invocation.positionalArguments.single as int),
      );
      when(
        () => repo.list(
          typeId: any(named: 'typeId'),
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
        ),
      ).thenAnswer((_) async => const <Permit>[]);
      Get.put<PermitRepository>(repo);

      await tester.pumpWidget(
        GetMaterialApp(
          locale: const Locale('id', 'ID'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('id', 'ID')],
          initialRoute: '/start',
          getPages: [
            GetPage(
              name: '/start',
              page: () => const Scaffold(body: Text('Beranda')),
            ),
            ...PermitPages.pages,
          ],
        ),
      );
    }

    testWidgets('returns to where the detail was opened from', (tester) async {
      await pumpApp(tester);

      Get.toNamed(PermitRoutes.show, arguments: {'id': 1});
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('Beranda'), findsOneWidget);
    });

    testWidgets('opened on its own, goes to the list of its kind', (
      tester,
    ) async {
      await pumpApp(tester);

      Get.offAllNamed(PermitRoutes.show, arguments: {'id': 1});
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, PermitRoutes.list);
      verify(
        () => repo.list(
          typeId: 1,
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
        ),
      ).called(1);
    });
  });
}
