import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/itms/data/models/itms_knowledge_article.dart';
import 'package:esas/features/itms/data/models/itms_service.dart';
import 'package:esas/features/itms/data/models/itms_ticket.dart';
import 'package:esas/features/itms/data/repositories/itms_repository.dart';
import 'package:esas/features/itms/presentation/controllers/itms_dashboard_controller.dart';
import 'package:esas/features/itms/presentation/controllers/itms_ticket_create_controller.dart';
import 'package:esas/features/itms/presentation/routes/itms_routes.dart';
import 'package:esas/features/itms/presentation/views/itms_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements ItmsRepository {}

ItmsTicket _ticket(int id, String status) =>
    ItmsTicket.fromJson({'id': id, 'subject': 'Tiket $id', 'status': status});

/// ITMS-01. "Lapor" opened the dashboard it sat on — nothing on screen could
/// file a ticket — and "N tiket kendala aktif" counted the closed ones.
void main() {
  late _Repo repo;

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
    when(() => repo.services()).thenAnswer(
      (_) async => [
        ItmsService.fromJson({'id': 4, 'code': 'NET', 'name': 'Jaringan'}),
        ItmsService.fromJson({'id': 5, 'code': 'HW', 'name': 'Perangkat'}),
      ],
    );
    when(
      () => repo.knowledgeArticles(),
    ).thenAnswer((_) async => <ItmsKnowledgeArticle>[]);
  });

  tearDown(Get.reset);

  group('the dashboard', () {
    test('counts only tickets still open', () async {
      when(() => repo.tickets()).thenAnswer(
        (_) async => [
          _ticket(1, 'resolved'),
          _ticket(2, 'closed'),
          _ticket(3, 'in_progress'),
        ],
      );
      final controller = ItmsDashboardController(repository: repo);
      await controller.loadDashboard();

      expect(controller.activeTickets.map((t) => t.id), [3]);
    });

    testWidgets('"Lapor" opens a form that files a ticket', (tester) async {
      when(() => repo.tickets()).thenAnswer((_) async => <ItmsTicket>[]);
      Get.put(ItmsDashboardController(repository: repo));

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          initialRoute: ItmsRoutes.itms,
          getPages: [
            GetPage(
              name: ItmsRoutes.itms,
              page: () => const ItmsDashboardView(),
            ),
            GetPage(
              name: ItmsRoutes.ticketCreate,
              page: () => const Scaffold(body: Text('FORM TIKET')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lapor'));
      await tester.pumpAndSettle();

      expect(find.text('FORM TIKET'), findsOneWidget);
    });
  });

  group('filing a ticket', () {
    late ItmsTicketCreateController controller;

    setUp(() async {
      controller = ItmsTicketCreateController(repository: repo);
      await controller.loadServices();
    });

    test('mirrors the server rules before asking it', () {
      expect(controller.validate(), contains('layanan'));

      controller.serviceId.value = 4;
      expect(controller.validate(), contains('Judul'));

      controller.subjectC.text = 'x' * 256;
      expect(controller.validate(), contains('255'));

      controller.subjectC.text = 'Wi-Fi lantai 3 mati';
      controller.descriptionC.text = 'y' * 4001;
      expect(controller.validate(), contains('4000'));

      controller.descriptionC.text = '';
      expect(controller.validate(), isNull);
    });

    test('sends what was typed, once', () async {
      when(
        () => repo.createTicket(
          serviceId: any(named: 'serviceId'),
          subject: any(named: 'subject'),
          description: any(named: 'description'),
        ),
      ).thenAnswer((_) async {});
      controller.serviceId.value = 4;
      controller.subjectC.text = '  Wi-Fi lantai 3 mati ';
      controller.descriptionC.text = '   ';

      final results = await Future.wait([
        controller.submit(),
        controller.submit(),
      ]);

      expect(results, [true, false]);
      verify(
        () => repo.createTicket(
          serviceId: 4,
          subject: 'Wi-Fi lantai 3 mati',
          description: null,
        ),
      ).called(1);
    });

    test('a refusal is explained on the form', () async {
      when(
        () => repo.createTicket(
          serviceId: any(named: 'serviceId'),
          subject: any(named: 'subject'),
          description: any(named: 'description'),
        ),
      ).thenThrow(
        const ApiException(
          'The given data was invalid.',
          status: 422,
          errors: {'service_id': 'Layanan tidak ditemukan.'},
        ),
      );
      controller.serviceId.value = 4;
      controller.subjectC.text = 'Wi-Fi mati';

      expect(await controller.submit(), isFalse);
      expect(controller.error.value, 'Layanan tidak ditemukan.');
    });
  });
}
