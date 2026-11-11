import 'package:flutter_test/flutter_test.dart';
import 'package:esas/features/profile/data/models/company_policy.dart';
import 'package:esas/features/profile/data/models/device_session.dart';
import 'package:esas/features/profile/data/models/performance_plan.dart';
import 'package:esas/features/profile/data/models/worker_skill.dart';

void main() {
  group('Extended Profile Models Test', () {
    test('parses DeviceSession json correctly', () {
      final json = {
        'id': 1,
        'device_id': 'pixel-7-pro',
        'is_registered_device': true,
        'is_current': true,
        'abilities': ['attendance', 'profile', 'permits'],
        'last_used_at': '2026-11-11T12:00:00Z',
      };

      final session = DeviceSession.fromJson(json);
      expect(session.id, 1);
      expect(session.deviceId, 'pixel-7-pro');
      expect(session.isRegisteredDevice, true);
      expect(session.isCurrent, true);
      expect(session.abilities, contains('attendance'));
    });

    test('parses PerformancePlan json correctly', () {
      final json = {
        'id': 8,
        'cycle_name': 'KPI Tahunan 2026',
        'period_start': '2026-01-01',
        'period_end': '2026-12-31',
        'status': 'frozen',
        'status_label': 'Disepakati',
        'total_weight': 100.0,
      };

      final plan = PerformancePlan.fromJson(json);
      expect(plan.id, 8);
      expect(plan.cycleName, 'KPI Tahunan 2026');
      expect(plan.status, 'frozen');
      expect(plan.totalWeight, 100.0);
    });

    test('parses CompanyPolicy json correctly', () {
      final json = {
        'id': 14,
        'number': 'POL-HR-2026-01',
        'title': 'Peraturan Perusahaan 2026',
        'category': 'HR Policies',
        'current_version': '2.1',
        'summary': 'Pedoman tata tertib dan hak kewajiban karyawan.',
        'effective_date': '2026-01-01',
      };

      final policy = CompanyPolicy.fromJson(json);
      expect(policy.id, 14);
      expect(policy.number, 'POL-HR-2026-01');
      expect(policy.currentVersion, '2.1');
    });

    test('parses WorkerSkill json correctly', () {
      final json = {
        'id': 3,
        'skill_name': 'Flutter & Dart Mobile Development',
        'skill_code': 'SK-MOB-01',
        'category': 'Engineering',
        'level_name': 'Mahir',
        'level_score': 4,
        'status': 'verified',
        'certificate_number': 'CERT-2026-0099',
      };

      final skill = WorkerSkill.fromJson(json);
      expect(skill.id, 3);
      expect(skill.skillName, 'Flutter & Dart Mobile Development');
      expect(skill.levelName, 'Mahir');
      expect(skill.levelScore, 4);
      expect(skill.status, 'verified');
    });
  });
}
