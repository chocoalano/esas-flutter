import 'package:esas/features/gams/data/models/gams_service_request.dart';
import 'package:esas/features/gams/data/models/gams_space_reservation.dart';
import 'package:esas/features/gams/data/models/gams_vehicle_booking.dart';
import 'package:esas/features/gams/data/models/gams_visitor_pass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GAMS models test', () {
    test('parses GamsServiceRequest json correctly', () {
      final json = {
        'id': 101,
        'number': 'SR-00000101',
        'subject': 'AC Ruang Rapat Lt 2 Bocor',
        'description': 'Perlu perbaikan segera',
        'priority': 'high',
        'status': 'triage',
        'service_definition': 'Perbaikan Fasilitas Kantor',
        'facility': 'Gedung Utama',
        'created_at': '2026-11-11T08:00:00Z',
      };

      final req = GamsServiceRequest.fromJson(json);
      expect(req.id, 101);
      expect(req.number, 'SR-00000101');
      expect(req.subject, 'AC Ruang Rapat Lt 2 Bocor');
      expect(req.status, 'triage');
      expect(req.statusLabel, 'Dalam Peninjauan');
      expect(req.isClosed, isFalse);
    });

    test('parses GamsSpaceReservation json correctly', () {
      final json = {
        'id': 55,
        'space_id': 3,
        'space_name': 'Ruang Rapat Merbabu',
        'space_kind': 'Meeting Room',
        'zone_name': 'Lantai 2',
        'start_at': '2026-11-12T09:00:00Z',
        'end_at': '2026-11-12T11:00:00Z',
        'status': 'confirmed',
      };

      final res = GamsSpaceReservation.fromJson(json);
      expect(res.id, 55);
      expect(res.spaceName, 'Ruang Rapat Merbabu');
      expect(res.isConfirmed, isTrue);
      expect(res.isCancelled, isFalse);
    });

    test('parses GamsVehicleBooking json correctly', () {
      final json = {
        'id': 20,
        'number': 'VB-000020',
        'vehicle_id': 2,
        'vehicle_name': 'Toyota Avanza',
        'vehicle_plate': 'B 1234 ESAS',
        'purpose': 'Kunjungan Client Cibitung',
        'starts_at': '2026-11-13T08:00:00Z',
        'ends_at': '2026-11-13T17:00:00Z',
        'status': 'booking',
      };

      final vb = GamsVehicleBooking.fromJson(json);
      expect(vb.id, 20);
      expect(vb.number, 'VB-000020');
      expect(vb.vehicleName, 'Toyota Avanza');
      expect(vb.isBooking, isTrue);
    });

    test('parses GamsVisitorPass json correctly', () {
      final json = {
        'id': 12,
        'number': 'VIS-000012',
        'visitor_name': 'John Doe',
        'visitor_company': 'PT Vendor Solusi',
        'purpose': 'Presentasi Server Migration',
        'status': 'pre_register',
        'facility': 'Head Office',
      };

      final vp = GamsVisitorPass.fromJson(json);
      expect(vp.id, 12);
      expect(vp.visitorName, 'John Doe');
      expect(vp.statusLabel, 'Terdaftar (Pra-Kunjungan)');
    });
  });
}
