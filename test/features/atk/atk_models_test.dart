import 'package:esas/features/atk/data/models/atk_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('requester', () {
    test('a list page reads its rows and whether more follow', () {
      final page = AtkPage.fromJson({
        'data': [
          {
            'id': 4,
            'number': 'IR-0004',
            'item_name': 'Pulpen',
            'location_name': 'Gudang GA',
            'quantity': 5,
            'unit': 'pcs',
            'status': 'reserved',
            'status_label': 'Direservasi',
            'issued_quantity': 2,
            'awaiting_receipt': true,
            'created_at': '2026-11-12T03:00:00Z',
          },
        ],
        'meta': {'current_page': 1, 'last_page': 3, 'total': 41},
      }, AtkRequest.fromJson);

      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(page.total, 41);

      final request = page.items.single;
      expect(request.number, 'IR-0004');
      expect(request.statusLabel, 'Direservasi');
      expect(request.issuedQuantity, 2);
      expect(request.awaitingReceipt, isTrue);
      expect(request.isFullyIssued, isFalse);
    });

    test('a missing status label falls back to the Indonesian name', () {
      final request = AtkRequest.fromJson({'id': 1, 'status': 'rejected'});

      expect(request.statusLabel, 'Ditolak');
      expect(
        AtkPage.fromJson(const {'data': []}, AtkRequest.fromJson).hasMore,
        isFalse,
      );
    });

    test('a detail carries the reason and every handover', () {
      final detail = AtkRequestDetail.fromJson({
        'id': 4,
        'number': 'IR-0004',
        'item_name': 'Kertas A4',
        'unit': 'rim',
        'location_name': 'Lantai 2',
        'quantity': 3,
        'status': 'reserved',
        'status_label': 'Direservasi',
        'reason': null,
        'issued_quantity': 3,
        'issues': [
          {
            'id': 10,
            'number': 'ISS-10',
            'quantity': 1,
            'issued_by_name': 'Sari GA',
            'issued_at': '2026-11-12T03:00:00Z',
            'received_at': '2026-11-12T04:00:00Z',
            'can_acknowledge': false,
          },
          {
            'id': 11,
            'number': 'ISS-11',
            'quantity': 2,
            'issued_by_name': 'Sari GA',
            'issued_at': '2026-11-13T03:00:00Z',
            'received_at': null,
            'can_acknowledge': true,
          },
        ],
      });

      expect(detail.unit, 'rim');
      expect(detail.isFullyIssued, isTrue);
      expect(detail.issues, hasLength(2));
      expect(detail.issues.first.isReceived, isTrue);
      expect(detail.issues.last.canAcknowledge, isTrue);
      expect(detail.awaitsMyConfirmation, isTrue);
    });
  });

  group('desk', () {
    test('a desk detail reads stock, movements and allowed actions', () {
      final detail = AtkDeskDetail.fromJson({
        'id': 8,
        'number': 'IR-0008',
        'item_name': 'Map plastik',
        'item_code': 'ATK-MAP',
        'unit': 'pcs',
        'location_name': 'Gudang GA',
        'quantity': 10,
        'status': 'reserved',
        'status_label': 'Direservasi',
        'lock_version': 3,
        'requester_name': 'Budi',
        'reason': null,
        'issued_quantity': 4,
        'stock': {'on_hand': 30, 'reserved': 10, 'available': 20},
        'issues': [
          {
            'id': 1,
            'number': 'ISS-1',
            'quantity': 4,
            'issued_by_name': 'Sari GA',
            'issued_at': '2026-11-12T03:00:00Z',
            'received_by_name': 'Budi',
            'received_at': '2026-11-12T05:00:00Z',
          },
        ],
        'movements': [
          {'command': 'reserve', 'quantity': 10, 'at': '2026-11-11T03:00:00Z'},
          {'command': 'issue', 'quantity': 4, 'at': '2026-11-12T03:00:00Z'},
        ],
        'allowed_actions': ['issue'],
      });

      expect(detail.request.lockVersion, 3);
      expect(detail.request.itemCode, 'ATK-MAP');
      expect(detail.request.requesterName, 'Budi');
      expect(detail.request.allows(AtkDeskAction.issue), isTrue);
      expect(detail.request.allows(AtkDeskAction.reserve), isFalse);
      expect(detail.request.needsAction, isTrue);
      expect(detail.stock.available, 20);
      expect(detail.stock.reserved, 10);
      expect(detail.stock.onHand, 30);
      expect(detail.remaining, 6);
      expect(detail.issues.single.receivedByName, 'Budi');
      expect(detail.movements.map((m) => m.label), ['Reservasi', 'Penyerahan']);
    });

    test('no allowed actions means nothing waits on the officer', () {
      final request = AtkDeskRequest.fromJson({
        'id': 2,
        'status': 'requested',
        'allowed_actions': [],
      });

      expect(request.needsAction, isFalse);
      expect(request.statusLabel, 'Diajukan');
    });
  });
  group('returns', () {
    const returnRow = {
      'id': 5,
      'number': 'RTN-0005',
      'issue_id': 1,
      'quantity': 2,
      'reason': 'Kemasan rusak',
      'returned_by_name': 'Sari GA',
      'returned_at': '2026-11-13T02:00:00Z',
    };

    test('a return row reads every field', () {
      final entry = AtkReturn.fromJson(returnRow);

      expect(entry.id, 5);
      expect(entry.number, 'RTN-0005');
      expect(entry.issueId, 1);
      expect(entry.quantity, 2);
      expect(entry.reason, 'Kemasan rusak');
      expect(entry.returnedByName, 'Sari GA');
      expect(entry.returnedAt, '2026-11-13T02:00:00Z');
    });

    test('a desk detail reads what came back and what still may', () {
      final detail = AtkDeskDetail.fromJson({
        'id': 8,
        'number': 'IR-0008',
        'unit': 'rim',
        'quantity': 5,
        'status': 'reserved',
        'issued_quantity': 5,
        'returned_quantity': 2,
        'issues': [
          {
            'id': 1,
            'number': 'ISS-1',
            'quantity': 3,
            'received_at': '2026-11-12T05:00:00Z',
            'returned_quantity': 2,
            'returnable_quantity': 1,
            'can_return': true,
          },
          {
            'id': 2,
            'number': 'ISS-2',
            'quantity': 2,
            'returned_quantity': 0,
            // The server may know of goods but not allow a return yet.
            'returnable_quantity': 2,
            'can_return': false,
          },
        ],
        'returns': [returnRow],
      });

      expect(detail.returnedQuantity, 2);
      expect(detail.returns.single.number, 'RTN-0005');
      final first = detail.issueById(1)!;
      expect(first.returnedQuantity, 2);
      expect(first.returnableQuantity, 1);
      expect(first.canReturn, isTrue);
      expect(first.isReturnable, isTrue);
      expect(detail.issueById(2)!.isReturnable, isFalse);
      expect(detail.issueById(99), isNull);
    });

    test('can_return with nothing left to return offers no return', () {
      final issue = AtkHandover.fromJson({
        'id': 1,
        'can_return': true,
        'returnable_quantity': 0,
      });

      expect(issue.isReturnable, isFalse);
    });

    test('a requester detail reads its returns and each handover\'s', () {
      final detail = AtkRequestDetail.fromJson({
        'id': 4,
        'number': 'IR-0004',
        'unit': 'rim',
        'quantity': 3,
        'status': 'reserved',
        'issued_quantity': 3,
        'returned_quantity': 2,
        'issues': [
          {'id': 1, 'number': 'ISS-1', 'quantity': 3, 'returned_quantity': 2},
        ],
        'returns': [returnRow],
      });

      expect(detail.returnedQuantity, 2);
      expect(detail.returns.single.reason, 'Kemasan rusak');
      expect(detail.issues.single.returnedQuantity, 2);
      // The requester is never offered a return.
      expect(detail.issues.single.isReturnable, isFalse);
    });

    test('a server older than returns reads as nothing returned', () {
      const issue = {'id': 1, 'number': 'ISS-1', 'quantity': 3};
      final desk = AtkDeskDetail.fromJson({
        'id': 8,
        'status': 'reserved',
        'issues': [issue],
      });
      final mine = AtkRequestDetail.fromJson({
        'id': 4,
        'status': 'reserved',
        'issues': [issue],
      });

      expect(desk.returnedQuantity, 0);
      expect(desk.returns, isEmpty);
      expect(desk.issues.single.returnedQuantity, 0);
      expect(desk.issues.single.returnableQuantity, 0);
      expect(desk.issues.single.canReturn, isFalse);
      expect(mine.returnedQuantity, 0);
      expect(mine.returns, isEmpty);
      expect(mine.issues.single.returnedQuantity, 0);
    });

    test('malformed return fields fall back instead of throwing', () {
      final detail = AtkDeskDetail.fromJson({
        'id': 8,
        'returned_quantity': null,
        'returns': 'none',
        'issues': [
          {'id': 1, 'returnable_quantity': '2', 'can_return': 1},
        ],
      });

      expect(detail.returnedQuantity, 0);
      expect(detail.returns, isEmpty);
      expect(detail.issues.single.returnableQuantity, 2);
    });
  });
}
