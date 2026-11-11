import 'package:esas/features/attendance/data/models/overtime_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OvertimeEntry tests', () {
    test('parses overtime entry json and resolves status correctly', () {
      final json = {
        'id': 'ov-001',
        'date': '2026-11-10',
        'day_type': 'workday',
        'status': 'approved',
        'hours_approved': 3.0,
        'hours_worked': 3.5,
        'reason': 'Production monthly closing',
      };

      final entry = OvertimeEntry.fromJson(json);

      expect(entry.id, 'ov-001');
      expect(entry.date, '2026-11-10');
      expect(entry.isApproved, isTrue);
      expect(entry.isRejected, isFalse);
      expect(entry.isPending, isFalse);
      expect(entry.statusLabel, 'Disetujui');
      expect(entry.hoursApproved, 3.0);
      expect(entry.hoursWorked, 3.5);
      expect(entry.reason, 'Production monthly closing');
    });

    test('handles rejected and pending status labels', () {
      final rejected = OvertimeEntry.fromJson({'status': 'rejected'});
      expect(rejected.isRejected, isTrue);
      expect(rejected.statusLabel, 'Ditolak');

      final pending = OvertimeEntry.fromJson({'status': 'pending'});
      expect(pending.isPending, isTrue);
      expect(pending.statusLabel, 'Menunggu');
    });
  });
}
