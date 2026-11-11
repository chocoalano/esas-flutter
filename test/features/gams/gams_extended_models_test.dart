import 'package:flutter_test/flutter_test.dart';
import 'package:esas/features/gams/data/models/gams_package.dart';
import 'package:esas/features/gams/data/models/gate_pass.dart';
import 'package:esas/features/gams/data/models/inventory_request.dart';
import 'package:esas/features/gams/data/models/parking_permit.dart';

void main() {
  group('GAMS Extended Models Test', () {
    test('parses GamsPackage json correctly', () {
      final json = {
        'id': 1,
        'tracking_number': 'JNE-12345',
        'recipient_worker_uid': 'W-001',
        'courier': 'JNE Express',
        'sender': 'Vendor IT',
        'status': 'received',
        'status_label': 'Tiba di Mailroom',
        'received_at': '2026-11-11T08:00:00Z',
      };

      final pkg = GamsPackage.fromJson(json);
      expect(pkg.id, 1);
      expect(pkg.trackingNumber, 'JNE-12345');
      expect(pkg.courier, 'JNE Express');
      expect(pkg.status, 'received');
    });

    test('parses GatePass json correctly', () {
      final json = {
        'id': 20,
        'number': 'GP-00000020',
        'facility_id': 3,
        'facility_name': 'Headquarters',
        'status': 'approved',
        'status_label': 'Disetujui',
        'item_count': 4,
        'carrier_or_actor': 'Logistics Team',
      };

      final pass = GatePass.fromJson(json);
      expect(pass.id, 20);
      expect(pass.number, 'GP-00000020');
      expect(pass.itemCount, 4);
      expect(pass.status, 'approved');
    });

    test('parses ParkingPermit json correctly', () {
      final json = {
        'id': 5,
        'number': 'PK-0005',
        'area_name': 'Basement B1',
        'license_plate': 'B 1234 CD',
        'status': 'allocated',
        'status_label': 'Aktif',
        'slot_number': 'B1-12',
      };

      final permit = ParkingPermit.fromJson(json);
      expect(permit.id, 5);
      expect(permit.licensePlate, 'B 1234 CD');
      expect(permit.slotNumber, 'B1-12');
    });

    test('parses InventoryRequest json correctly', () {
      final json = {
        'id': 12,
        'number': 'IR-0012',
        'item_name': 'Kertas A4 80gr',
        'location_name': 'Gudang GA Pusat',
        'quantity': 5,
        'unit': 'rim',
        'status': 'requested',
        'status_label': 'Diajukan',
      };

      final req = InventoryRequest.fromJson(json);
      expect(req.id, 12);
      expect(req.itemName, 'Kertas A4 80gr');
      expect(req.quantity, 5);
      expect(req.unit, 'rim');
    });
  });
}
