import 'package:flutter_test/flutter_test.dart';
import 'package:esas/features/itms/data/models/itms_asset.dart';

void main() {
  group('ItmsAsset model test', () {
    test('parses ItmsAsset correctly and checks acknowledgement status', () {
      final json = {
        'id': 101,
        'asset_id': 55,
        'asset_tag': 'IT-NB-001',
        'asset_name': 'ThinkPad T14s',
        'serial_number': 'SN12345678',
        'asset_class': 'laptop',
        'custody_status': 'assigned',
        'deployed_at': '2026-11-10T10:00:00Z',
        'acknowledged_at': null,
        'returned_at': null,
        'movement_reference': 'MOV-001',
      };

      final asset = ItmsAsset.fromJson(json);

      expect(asset.id, 101);
      expect(asset.assetId, 55);
      expect(asset.assetTag, 'IT-NB-001');
      expect(asset.assetName, 'ThinkPad T14s');
      expect(asset.isAcknowledged, false);
      expect(asset.needsAcknowledgement, true);

      final acknowledgedJson = Map<String, dynamic>.from(json)
        ..['custody_status'] = 'in_custody'
        ..['acknowledged_at'] = '2026-11-11T09:00:00Z';

      final ackAsset = ItmsAsset.fromJson(acknowledgedJson);
      expect(ackAsset.isAcknowledged, true);
      expect(ackAsset.needsAcknowledgement, false);
    });
  });
}
