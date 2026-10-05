import 'package:esas/core/config/env.dart';
import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/features/setup/data/repositories/workspace_repository.dart';
import 'package:esas/features/setup/data/services/workspace_api_service.dart';
import 'package:esas/features/setup/presentation/controllers/setup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Future<SetupController> _controller() async {
  final store = InMemorySecureStore();
  final serverConfig = ServerConfig(store: store);
  final tenantContext = TenantContext(store: store);

  await serverConfig.restore();
  await tenantContext.restore();

  return SetupController(
    repository: WorkspaceRepository(
      serverConfig: serverConfig,
      tenantContext: tenantContext,
      api: WorkspaceApiService(
        probe: (url, headers) async => (status: 200, body: null),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SetupController controller;

  setUp(() async {
    controller = await _controller();
  });

  tearDown(() {
    controller.onClose();
  });

  group('validation', () {
    test('an empty field is refused before anything is sent', () {
      expect(controller.validateDomain(''), isNotNull);
      expect(controller.validateWorkspace('  '), isNotNull);
    });

    test('a typed phrase is not an address', () {
      // `Uri.tryParse` percent-encodes a space rather than failing, so without
      // `isPlausibleHost` this reads back to the person as "the server is down".
      expect(controller.validateDomain('not an address'), isNotNull);
      expect(controller.validateDomain('hrms.example.com'), isNull);
    });

    test('a workspace must be a DNS label', () {
      expect(controller.validateWorkspace('acme'), isNull);
      expect(controller.validateWorkspace('acme-nusantara'), isNull);
      expect(controller.validateWorkspace('acme corp'), isNotNull);
      expect(controller.validateWorkspace('https://acme'), isNotNull);
    });
  });

  group('what the screen shows about what is typed', () {
    test('the preview names this client\'s own API root', () {
      controller.domainController.text = 'hrms.example.com';
      controller.workspaceController.text = 'acme';
      controller.subdomainMode.value = true;

      expect(
        controller.preview,
        'https://acme.hrms.example.com${Env.apiPrefix}',
      );
    });

    test('single-host mode leaves the workspace out of the host', () {
      controller.domainController.text = 'hrms.example.com';
      controller.workspaceController.text = 'acme';
      controller.subdomainMode.value = false;

      expect(controller.preview, 'https://hrms.example.com${Env.apiPrefix}');
    });

    test('an IP cannot carry a workspace, and the switch says so', () {
      controller.domainController.text = '172.16.2.233:8000';
      controller.workspaceController.text = 'acme';
      controller.subdomainMode.value = true;

      // The switch is left on, but it is not in force — and the preview agrees
      // with the behaviour rather than with the switch.
      expect(controller.supportsSubdomain, isFalse);
      expect(controller.usesSubdomain, isFalse);
      expect(controller.preview, 'http://172.16.2.233:8000${Env.apiPrefix}');
    });

    test('an unencrypted address is called out', () {
      controller.domainController.text = 'http://hrms.example.com';
      expect(controller.isInsecure, isTrue);

      controller.domainController.text = 'hrms.example.com';
      expect(controller.isInsecure, isFalse);
    });
  });

  group('explaining a refusal', () {
    // The whole reason this screen makes a request of its own: a sign-in
    // answers a wrong address, a wrong workspace and a wrong password the same
    // way, and the person then retypes the password — the one thing that was
    // right.
    test('404 blames the workspace, by name', () {
      final message = SetupController.explain(
        const ApiException('Not Found', status: 404),
        'ghost',
      );

      expect(message, contains('ghost'));
      expect(message, contains('workspace'));
    });

    test('a transport failure blames the address or the network', () {
      final message = SetupController.explain(
        const ApiException('Tidak ada koneksi internet.'),
        'acme',
      );

      expect(message, contains('tidak dapat dihubungi'));
    });

    test('400 blames how the workspace was written', () {
      expect(
        SetupController.explain(
          const ApiException('Bad Request', status: 400),
          'acme',
        ),
        contains('penulisannya'),
      );
    });

    test('429 asks for patience, 5xx blames the server', () {
      expect(
        SetupController.explain(
          const ApiException('Too Many Requests', status: 429),
          'acme',
        ),
        contains('Tunggu'),
      );
      expect(
        SetupController.explain(
          const ApiException('Server Error', status: 503),
          'acme',
        ),
        contains('administrator'),
      );
    });

    test('anything else keeps what the server said', () {
      expect(
        SetupController.explain(
          const ApiException('Workspace dinonaktifkan.', status: 409),
          'acme',
        ),
        'Workspace dinonaktifkan.',
      );
    });
  });

  group('a confirmation is about the values that were checked', () {
    test('editing a field withdraws it', () async {
      controller.confirmedName.value = 'PT Acme Nusantara';
      controller.onInit();

      controller.workspaceController.text = 'globex';

      // Left standing over an edited field, the confirmation would offer a way
      // onward for an address nothing has ever reached.
      expect(controller.confirmedName.value, isNull);
    });
  });
}
