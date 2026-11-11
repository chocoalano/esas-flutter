import 'package:esas/features/home/data/models/announcement.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/controllers/announcement_controller.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/features/home/presentation/views/announcement_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements HomeRepository {}

/// HOME-02. Opened from the home screen with `offAllNamed`, the announcement
/// screens were the whole stack; the system back button closed the app.
void main() {
  setUpAll(initializeDateFormatting);
  tearDown(Get.reset);

  Future<void> pumpApp(WidgetTester tester) async {
    Get.testMode = true;
    final repo = _Repo();
    when(
      () => repo.announcements(
        page: any(named: 'page'),
        perPage: any(named: 'perPage'),
      ),
    ).thenAnswer((_) async => const <Announcement>[]);

    Get.put(AnnouncementController(repository: repo), permanent: true);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: HomeRoutes.home,
        getPages: [
          GetPage(
            name: HomeRoutes.home,
            page: () => const Scaffold(body: Text('Beranda')),
          ),
          GetPage(
            name: HomeRoutes.announcement,
            page: () => const AnnouncementView(),
          ),
        ],
      ),
    );
  }

  testWidgets('from the home screen, back returns to it', (tester) async {
    await pumpApp(tester);

    Get.toNamed(HomeRoutes.announcement);
    await tester.pumpAndSettle();
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('Beranda'), findsOneWidget);
  });

  testWidgets('as the whole stack, back goes home, not out', (tester) async {
    await pumpApp(tester);

    Get.offAllNamed(HomeRoutes.announcement);
    await tester.pumpAndSettle();
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('Beranda'), findsOneWidget);
  });
}
