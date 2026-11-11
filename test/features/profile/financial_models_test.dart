import 'package:esas/features/profile/data/models/cash_advance.dart';
import 'package:esas/features/profile/data/models/employee_loan.dart';
import 'package:esas/features/profile/data/models/expense_claim.dart';
import 'package:esas/features/profile/data/models/travel_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Financial models test', () {
    test('parses employee loan json correctly', () {
      final json = {
        'loans': [
          {
            'reference': 'LN-2026-001',
            'purpose': 'Renovasi Rumah',
            'principal': 10000000,
            'repaid': 2000000,
            'outstanding': 8000000,
            'instalments_left': 8,
            'instalment_amount': 1000000,
          }
        ],
        'outstanding_total': 8000000.0,
      };

      final response = LoansResponse.fromJson(json);
      expect(response.outstandingTotal, 8000000.0);
      expect(response.loans.length, 1);

      final loan = response.loans.first;
      expect(loan.reference, 'LN-2026-001');
      expect(loan.purpose, 'Renovasi Rumah');
      expect(loan.principal, 10000000.0);
      expect(loan.repaid, 2000000.0);
      expect(loan.outstanding, 8000000.0);
      expect(loan.instalmentsLeft, 8);
      expect(loan.instalmentAmount, 1000000.0);
    });

    test('parses cash advance json correctly', () {
      final json = {
        'advances': [
          {
            'reference': 'ADV-2026-001',
            'purpose': 'Perjalanan Dinas',
            'amount': 2500000,
            'disbursed_at': '2026-11-05',
          }
        ],
        'unaccounted_total': 2500000.0,
      };

      final response = AdvancesResponse.fromJson(json);
      expect(response.unaccountedTotal, 2500000.0);
      expect(response.advances.length, 1);

      final advance = response.advances.first;
      expect(advance.reference, 'ADV-2026-001');
      expect(advance.purpose, 'Perjalanan Dinas');
      expect(advance.amount, 2500000.0);
      expect(advance.disbursedAt, '2026-11-05');
    });

    test('parses expense claim json correctly', () {
      final json = {
        'id': 101,
        'reference': 'EXP-2026-001',
        'title': 'Pembelian ATK Lapangan',
        'total': 450000.0,
        'status': 'submitted',
        'items_count': 3,
        'submitted_at': '2026-11-10T10:00:00Z',
      };

      final claim = ExpenseClaim.fromJson(json);
      expect(claim.id, 101);
      expect(claim.reference, 'EXP-2026-001');
      expect(claim.title, 'Pembelian ATK Lapangan');
      expect(claim.total, 450000.0);
      expect(claim.status, 'submitted');
      expect(claim.isSubmitted, isTrue);
      expect(claim.statusLabel, 'Diajukan');
      expect(claim.itemsCount, 3);
    });

    test('parses travel request json correctly', () {
      final json = {
        'id': 202,
        'reference': 'TRV-2026-001',
        'destination': 'Surabaya',
        'purpose': 'Audit Pabrik Cabang',
        'departs_on': '2026-11-15',
        'returns_on': '2026-11-17',
        'days': 3,
        'allowance_amount': 750000.0,
        'status': 'approved',
      };

      final trip = TravelRequest.fromJson(json);
      expect(trip.id, 202);
      expect(trip.reference, 'TRV-2026-001');
      expect(trip.destination, 'Surabaya');
      expect(trip.purpose, 'Audit Pabrik Cabang');
      expect(trip.departsOn, '2026-11-15');
      expect(trip.returnsOn, '2026-11-17');
      expect(trip.days, 3);
      expect(trip.allowanceAmount, 750000.0);
      expect(trip.status, 'approved');
      expect(trip.isApproved, isTrue);
      expect(trip.statusLabel, 'Disetujui');
    });
  });
}

