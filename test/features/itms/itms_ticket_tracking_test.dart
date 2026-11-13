import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/itms/data/models/itms_ticket.dart';
import 'package:esas/features/itms/data/repositories/itms_repository.dart';
import 'package:esas/features/itms/presentation/controllers/itms_ticket_detail_controller.dart';
import 'package:esas/features/itms/presentation/controllers/itms_ticket_list_controller.dart';
import 'package:esas/features/itms/presentation/views/itms_ticket_detail_view.dart';
import 'package:esas/features/itms/presentation/views/itms_ticket_list_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements ItmsRepository {}

/// FUNC-D04. A ticket vanished from the app the moment IT solved it: the
/// dashboard listed open tickets only, and no ticket could be opened.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _Repo repo;

  final open = ItmsTicket.fromJson({
    'id': 11,
    'service_id': 1,
    'service_name': 'Bantuan IT',
    'subject': 'Wi-Fi lantai 3 mati',
    'status': 'in_progress',
    'status_label': 'Dikerjakan',
    'created_at': '2026-11-10T02:00:00Z',
  });
  final solved = ItmsTicket.fromJson({
    'id': 12,
    'service_id': 1,
    'service_name': 'Bantuan IT',
    'subject': 'Laptop tidak menyala',
    'description': 'Mati total sejak pagi',
    'status': 'resolved',
    'status_label': 'Selesai',
    'resolution_notes': 'RAM diganti, laptop menyala normal',
    'is_assigned': true,
    'created_at': '2026-11-09T02:00:00Z',
    'triaged_at': '2026-11-09T03:00:00Z',
    'assigned_at': '2026-11-09T03:05:00Z',
    'started_at': '2026-11-09T04:00:00Z',
    'resolved_at': '2026-11-09T06:00:00Z',
  });

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
  });

  tearDown(Get.reset);

  test('the detail fields are read', () {
    expect(solved.isAssigned, isTrue);
    expect(solved.startedAt, '2026-11-09T04:00:00Z');
    expect(open.isAssigned, isFalse);
  });

  testWidgets('the list keeps solved tickets and opens any of them', (
    tester,
  ) async {
    when(
      () => repo.tickets(page: any(named: 'page')),
    ).thenAnswer((_) async => [open, solved]);
    Get.put(ItmsTicketListController(repository: repo));

    await tester.pumpWidget(const GetMaterialApp(home: ItmsTicketListView()));
    await tester.pumpAndSettle();

    expect(find.text('Wi-Fi lantai 3 mati'), findsOneWidget);
    expect(find.text('Laptop tidak menyala'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
  });

  testWidgets(
    'a solved ticket shows what IT reported, and says it is not final',
    (tester) async {
      when(() => repo.ticket(12)).thenAnswer((_) async => solved);
      Get.put(ItmsTicketDetailController(repository: repo, ticketId: 12));

      await tester.pumpWidget(
        const GetMaterialApp(home: ItmsTicketDetailView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hasil penyelesaian'), findsOneWidget);
      expect(find.text('RAM diganti, laptop menyala normal'), findsOneWidget);
      expect(
        find.textContaining('melaporkan tiket ini selesai'),
        findsOneWidget,
      );
      expect(find.textContaining('Mulai dikerjakan'), findsOneWidget);
      // Steps that did not happen are not listed.
      expect(find.textContaining('Ditutup'), findsNothing);
    },
  );

  testWidgets('a ticket that is not theirs reads as not found, with no retry', (
    tester,
  ) async {
    when(
      () => repo.ticket(99),
    ).thenThrow(const ApiException('Tidak ditemukan', status: 404));
    Get.put(ItmsTicketDetailController(repository: repo, ticketId: 99));

    await tester.pumpWidget(const GetMaterialApp(home: ItmsTicketDetailView()));
    await tester.pumpAndSettle();

    expect(find.text('Tiket tidak ditemukan'), findsOneWidget);
  });

  testWidgets(
    'the assigned technician is named; an unassigned ticket says it waits (D-05)',
    (tester) async {
      final handled = ItmsTicket.fromJson({
        'id': 41,
        'service_id': 1,
        'subject': 'Printer macet',
        'status': 'in_progress',
        'status_label': 'Dikerjakan',
        'is_assigned': true,
        'assignee_name': 'Rina Teknisi',
      });
      final waiting = ItmsTicket.fromJson({
        'id': 42,
        'service_id': 1,
        'subject': 'Wi-Fi lemah',
        'status': 'new',
        'status_label': 'Baru',
        'is_assigned': false,
      });
      when(() => repo.ticket(41)).thenAnswer((_) async => handled);
      when(() => repo.ticket(42)).thenAnswer((_) async => waiting);

      Get.put(ItmsTicketDetailController(repository: repo, ticketId: 41));
      await tester.pumpWidget(
        const GetMaterialApp(home: ItmsTicketDetailView()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ditangani oleh: Rina Teknisi'), findsOneWidget);
      expect(find.text('Petugas IT: Rina Teknisi'), findsOneWidget);

      Get.reset();
      Get.testMode = true;
      Get.put(ItmsTicketDetailController(repository: repo, ticketId: 42));
      await tester.pumpWidget(
        const GetMaterialApp(home: ItmsTicketDetailView()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Menunggu penugasan'), findsOneWidget);
    },
  );
}
