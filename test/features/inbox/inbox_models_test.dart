import 'package:esas/features/inbox/data/models/approval_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Unified Inbox models test', () {
    test('parses ApprovalTask json correctly and distinguishes domain tags', () {
      final hrmsJson = {
        'id': 'hrms_permit_123',
        'domain': 'hrms',
        'domain_label': 'HRMS Cuti/Izin',
        'item_id': 123,
        'title': 'Cuti Tahunan',
        'requester_name': 'Ahmad Fauzi',
        'requester_nip': 'EMP-2024-009',
        'notes': 'Acara keluarga',
        'status': 'waiting_approval',
      };

      final hrmsTask = ApprovalTask.fromJson(hrmsJson);
      expect(hrmsTask.id, 'hrms_permit_123');
      expect(hrmsTask.isHrms, isTrue);
      expect(hrmsTask.isGams, isFalse);
      expect(hrmsTask.isItms, isFalse);
      expect(hrmsTask.requesterName, 'Ahmad Fauzi');

      final gamsJson = {
        'id': 'gams_sr_45',
        'domain': 'gams',
        'domain_label': 'General Affairs',
        'item_id': 45,
        'title': 'Penggantian Lampu Koridor',
        'requester_name': 'Fasilitas Lt 1',
        'status': 'triage',
      };

      final gamsTask = ApprovalTask.fromJson(gamsJson);
      expect(gamsTask.isGams, isTrue);
      expect(gamsTask.isHrms, isFalse);

      final itmsJson = {
        'id': 'itms_ticket_89',
        'domain': 'itms',
        'domain_label': 'IT Helpdesk',
        'item_id': 89,
        'title': 'Akses Database Staging',
        'requester_name': 'Dev Team',
        'status': 'new',
      };

      final itmsTask = ApprovalTask.fromJson(itmsJson);
      expect(itmsTask.isItms, isTrue);
    });
  });

  // INBOX-02. The server says which tasks can be decided here; an ITMS ticket
  // cannot, and its Setujui/Tolak always failed with a 400.
  test('can_decide is read, and defaults to yes', () {
    expect(
      ApprovalTask.fromJson({'id': 'x', 'can_decide': false}).canDecide,
      isFalse,
    );
    expect(ApprovalTask.fromJson({'id': 'x'}).canDecide, isTrue);
  });
}
