import 'package:esas/core/config/env.dart';
import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/features/setup/data/models/workspace.dart';
import 'package:esas/features/setup/data/repositories/workspace_repository.dart';
import 'package:esas/features/setup/data/services/workspace_api_service.dart';
import 'package:esas/features/setup/presentation/controllers/setup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppEnvironment and Env', () {
    test('parses environment strings correctly', () {
      expect(AppEnvironment.fromString('production'), AppEnvironment.production);
      expect(AppEnvironment.fromString('prod'), AppEnvironment.production);
      expect(AppEnvironment.fromString('PROD'), AppEnvironment.production);
      expect(AppEnvironment.fromString(null), AppEnvironment.production);
      expect(AppEnvironment.fromString(''), AppEnvironment.production);

      expect(AppEnvironment.fromString('development'), AppEnvironment.development);
      expect(AppEnvironment.fromString('dev'), AppEnvironment.development);
      expect(AppEnvironment.fromString('local'), AppEnvironment.development);

      expect(AppEnvironment.fromString('staging'), AppEnvironment.staging);
      expect(AppEnvironment.fromString('uat'), AppEnvironment.staging);
    });

    test('defaultDomainFor provides correct domains per environment', () {
      expect(
        Env.defaultDomainFor(AppEnvironment.production),
        contains('absensas.com'),
      );
      expect(
        Env.defaultDomainFor(AppEnvironment.staging),
        contains('staging.absensas.com'),
      );
      expect(
        Env.defaultDomainFor(AppEnvironment.development),
        contains('10.0.2.2:8000'),
      );
    });
  });

  group('ServerConfig environment handling', () {
    test('inferEnvironment detects dev and staging hosts', () {
      expect(ServerConfig.inferEnvironment('http://10.0.2.2:8000'), 'development');
      expect(ServerConfig.inferEnvironment('http://localhost:8000'), 'development');
      expect(ServerConfig.inferEnvironment('http://esas.test:8000'), 'development');
      expect(ServerConfig.inferEnvironment('192.168.1.5:8000'), 'development');
      expect(ServerConfig.inferEnvironment('https://staging.absensas.com'), 'staging');
      expect(ServerConfig.inferEnvironment('https://absensas.com'), 'production');
      expect(ServerConfig.inferEnvironment('https://hrms.sinergi.co.id'), 'production');
    });

    test('saves and restores environment setting', () async {
      final store = InMemorySecureStore();
      final config = ServerConfig(store: store);

      await config.save(
        domain: 'https://absensas.com',
        subdomainMode: true,
        environment: 'production',
      );

      expect(config.environment, 'production');
      expect(config.appEnvironment, AppEnvironment.production);
      expect(config.isProduction, isTrue);
      expect(config.isDevelopment, isFalse);

      final restored = ServerConfig(store: store);
      await restored.restore();

      expect(restored.environment, 'production');
      expect(restored.appEnvironment, AppEnvironment.production);
      expect(restored.environmentLabel, 'Produksi');
    });
  });

  group('SetupController environment switching and validation', () {
    late SetupController controller;

    setUp(() async {
      final store = InMemorySecureStore();
      final serverConfig = ServerConfig(store: store);
      final tenantContext = TenantContext(store: store);

      await serverConfig.restore();
      await tenantContext.restore();

      controller = SetupController(
        repository: WorkspaceRepository(
          serverConfig: serverConfig,
          tenantContext: tenantContext,
          api: WorkspaceApiService(
            probe: (url, headers) async => (status: 200, body: {
              'subdomain': 'acme',
              'name': 'ACME Corp',
              'environment': 'development',
              'api_version': 'v1',
              'timezone': {
                'name': 'Asia/Jakarta',
                'abbreviation': 'WIB',
                'offset_minutes': 420,
              },
            }),
          ),
        ),
      );
    });

    tearDown(() {
      controller.onClose();
    });

    test('switching environment updates domain and subdomain mode', () {
      controller.selectEnvironment(AppEnvironment.production);
      expect(controller.selectedEnvironment.value, AppEnvironment.production);
      expect(controller.domainController.text, Env.defaultProductionDomain);
      expect(controller.subdomainMode.value, isTrue);

      controller.selectEnvironment(AppEnvironment.development);
      expect(controller.selectedEnvironment.value, AppEnvironment.development);
      expect(controller.domainController.text, Env.defaultEmulatorDomain);
      expect(controller.subdomainMode.value, isFalse);

      controller.selectEnvironment(AppEnvironment.staging);
      expect(controller.selectedEnvironment.value, AppEnvironment.staging);
      expect(controller.domainController.text, Env.defaultStagingDomain);
      expect(controller.subdomainMode.value, isTrue);
    });

    test('applyDevPreset sets address and adjusts subdomain mode', () {
      controller.selectEnvironment(AppEnvironment.development);

      controller.applyDevPreset('http://10.0.2.2:8000');
      expect(controller.domainController.text, 'http://10.0.2.2:8000');
      expect(controller.subdomainMode.value, isFalse); // IP literal

      controller.applyDevPreset('http://esas.test:8000');
      expect(controller.domainController.text, 'http://esas.test:8000');
      expect(controller.subdomainMode.value, isTrue); // DNS label
    });

    test('production mode uses fixed default domain and skips domain input', () {
      controller.selectEnvironment(AppEnvironment.production);

      // In production, domain is automatically set to fixed production domain
      expect(controller.domainController.text, Env.defaultProductionDomain);
      expect(controller.subdomainMode.value, isTrue);

      // In production mode, domain validator returns null as user does not fill this field
      expect(controller.validateDomain(''), isNull);
      expect(controller.validateDomain(null), isNull);
    });

    test('development mode validates required input and accepts HTTP/local IPs', () {
      controller.selectEnvironment(AppEnvironment.development);

      expect(controller.validateDomain(''), isNotNull);
      expect(controller.validateDomain('not an address'), isNotNull);
      expect(controller.validateDomain('http://10.0.2.2:8000'), isNull);
      expect(controller.validateDomain('10.0.2.2:8000'), isNull);
      expect(controller.validateDomain('localhost:8000'), isNull);
      expect(controller.validateDomain('http://esas.test:8000'), isNull);
    });

    test('check probes workspace and confirms name and environment', () async {
      controller.selectEnvironment(AppEnvironment.development);
      controller.domainController.text = 'http://10.0.2.2:8000';
      controller.workspaceController.text = 'acme';

      await controller.check();

      expect(controller.confirmedName.value, 'ACME Corp');
      expect(controller.checkError.value, isNull);
    });
  });

  group('Workspace model environment parsing', () {
    test('parses environment field from json', () {
      final ws = Workspace.fromJson({
        'subdomain': 'acme',
        'name': 'ACME Corp',
        'environment': 'local',
        'api_version': 'v1',
        'active_modules': ['hrms', 'gams'],
        'timezone': {
          'name': 'Asia/Jakarta',
          'abbreviation': 'WIB',
          'offset_minutes': 420,
        },
      }, fallback: 'fallback');

      expect(ws.subdomain, 'acme');
      expect(ws.name, 'ACME Corp');
      expect(ws.environment, 'local');
      expect(ws.apiVersion, 'v1');
      expect(ws.activeModules, contains('gams'));
    });
  });
}

