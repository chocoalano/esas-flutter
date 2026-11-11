import 'package:esas/core/registry/module_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModuleRegistry tests', () {
    test('Default HRMS modules return HRMS services and omit GAMS/ITMS', () {
      final services = ModuleRegistry.getAvailableServices(
        activeModules: ['hrms'],
        isManager: false,
      );

      final ids = services.map((s) => s.id).toList();
      expect(ids, contains('hrms_attendance'));
      expect(ids, contains('hrms_permit_create'));
      expect(ids, contains('hrms_schedule'));
      expect(ids, contains('hrms_overtime'));
      expect(ids, contains('hrms_financial'));
      expect(ids, contains('hrms_ai_chat'));

      // GAMS, ITMS, MTMS should NOT be included
      expect(ids, isNot(contains('gams_service_request')));
      expect(ids, isNot(contains('itms_tickets')));
      expect(ids, isNot(contains('mtms_work_orders')));

      // Manager-only items should NOT be included for normal staff
      expect(ids, isNot(contains('unified_inbox')));
    });

    test('Manager receives unified inbox', () {
      final services = ModuleRegistry.getAvailableServices(
        activeModules: ['hrms'],
        isManager: true,
      );

      final ids = services.map((s) => s.id).toList();
      expect(ids, contains('unified_inbox'));
    });

    test('When GAMS is active, GAMS services are dynamically included', () {
      final services = ModuleRegistry.getAvailableServices(
        activeModules: ['hrms', 'gams'],
        isManager: false,
      );

      final ids = services.map((s) => s.id).toList();
      expect(ids, contains('gams_service_request'));
      expect(ids, contains('gams_space_reservation'));
      expect(ids, contains('gams_vehicle_booking'));
      expect(ids, contains('gams_visitor_pass'));
      expect(ids, isNot(contains('itms_tickets')));
    });

    test('When ITMS is active, ITMS services are dynamically included', () {
      final services = ModuleRegistry.getAvailableServices(
        activeModules: ['hrms', 'itms'],
        isManager: false,
      );

      final ids = services.map((s) => s.id).toList();
      expect(ids, contains('itms_tickets'));
      expect(ids, contains('itms_catalog'));
      expect(ids, contains('itms_knowledge'));
      expect(ids, isNot(contains('gams_service_request')));
    });

    // CORE-06. MTMS has no page in this app yet; its tile pointed at a route
    // nothing answers and did nothing. An active MTMS module therefore adds no
    // tile until the page exists — `registry_routes_test.dart` pins that every
    // advertised tile opens a registered page.
    test('When MTMS is active, no tile is offered until its page exists', () {
      final services = ModuleRegistry.getAvailableServices(
        activeModules: ['hrms', 'mtms'],
        isManager: false,
      );

      final ids = services.map((s) => s.id).toList();
      expect(ids, isNot(contains('mtms_work_orders')));
      expect(ids, isNot(contains('gams_service_request')));
      expect(ids, isNot(contains('itms_tickets')));
    });

    test('Grouped by module organizes services into separate keys', () {
      final grouped = ModuleRegistry.getServicesGroupedByModule(
        activeModules: ['hrms', 'gams', 'itms'],
        isManager: true,
      );

      expect(grouped.containsKey('hrms'), isTrue);
      expect(grouped.containsKey('gams'), isTrue);
      expect(grouped.containsKey('itms'), isTrue);
      expect(grouped['hrms']!.isNotEmpty, isTrue);
      expect(grouped['gams']!.isNotEmpty, isTrue);
      expect(grouped['itms']!.isNotEmpty, isTrue);
    });
  });
}

