import 'package:esas/features/itms/data/models/itms_knowledge_article.dart';
import 'package:esas/features/itms/data/models/itms_service.dart';
import 'package:esas/features/itms/data/models/itms_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ITMS models test', () {
    test('parses ItmsTicket json correctly', () {
      final json = {
        'id': 301,
        'service_id': 12,
        'service_name': 'VPN & Remote Access',
        'service_code' : 'IT-SVC-012',
        'subject': 'Gagal konek VPN kantor dari rumah',
        'description': 'Muncul error TLS handshake',
        'status': 'triaged',
        'status_label': 'Ditelaah',
        'created_at': '2026-11-11T10:00:00Z',
      };

      final ticket = ItmsTicket.fromJson(json);
      expect(ticket.id, 301);
      expect(ticket.serviceName, 'VPN & Remote Access');
      expect(ticket.subject, 'Gagal konek VPN kantor dari rumah');
      expect(ticket.status, 'triaged');
      expect(ticket.statusLabel, 'Ditelaah');
      expect(ticket.isClosed, isFalse);
    });

    test('parses ItmsService json correctly', () {
      final json = {
        'id': 5,
        'code': 'IT-EMAIL',
        'name': 'Corporate Email & Google Workspace',
        'category': 'Identity & Communication',
      };

      final service = ItmsService.fromJson(json);
      expect(service.id, 5);
      expect(service.code, 'IT-EMAIL');
      expect(service.name, 'Corporate Email & Google Workspace');
      expect(service.category, 'Identity & Communication');
    });

    test('parses ItmsKnowledgeArticle json correctly', () {
      final json = {
        'id': 10,
        'title': 'Cara Setup MFA pada Handset Baru',
        'summary': 'Langkah-langkah registrasi aplikasi authenticator',
        'body': 'Buka menu profil lalu pilih keamanan...',
      };

      final article = ItmsKnowledgeArticle.fromJson(json);
      expect(article.id, 10);
      expect(article.title, 'Cara Setup MFA pada Handset Baru');
      expect(article.summary, contains('Langkah-langkah'));
    });
  });
}

