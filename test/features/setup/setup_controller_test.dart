import 'dart:async';

import 'package:esas/core/config/env.dart';
import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/features/setup/data/repositories/workspace_repository.dart';
import 'package:esas/features/setup/data/services/workspace_api_service.dart';
import 'package:esas/features/setup/presentation/controllers/setup_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

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

  group('remediasi setup', () {
    late InMemorySecureStore store;
    late WorkspaceRepository repository;
    late Completer<({int? status, Object? body})> answer;
    late SetupController setup;

    setUp(() async {
      Get.testMode = true;
      store = InMemorySecureStore();
      final serverConfig = ServerConfig(store: store);
      final tenantContext = TenantContext(store: store);
      await serverConfig.restore();
      await tenantContext.restore();
      answer = Completer();
      repository = WorkspaceRepository(
        serverConfig: serverConfig,
        tenantContext: tenantContext,
        api: WorkspaceApiService(probe: (url, headers) => answer.future),
      );
      setup = SetupController(repository: repository)..onInit();
      setup.domainController.text = 'hrms.example.com';
      setup.workspaceController.text = 'acme';
    });

    tearDown(() => setup.onClose());

    const found = (
      status: 200,
      body: {'subdomain': 'acme', 'name': 'PT Acme Nusantara'},
    );

    // SETUP-01. The workspace was saved the moment the server answered — before
    // the screen asked "is this your company?". A typo that reached another
    // real company locked the handset to it, with no way back from login.
    test('nothing is saved until the person goes on', () async {
      final checked = setup.check();
      answer.complete(found);
      await checked;

      expect(setup.confirmedName.value, 'PT Acme Nusantara');
      expect(repository.isConfigured, isFalse);

      await setup.proceed();

      expect(repository.isConfigured, isTrue);
      expect(repository.workspace, 'acme');
    });

    // UAT review C1. A start with no connection opens the login screen with the
    // stored session kept (CORE-04), and that screen links to Setup. Adopting
    // another workspace there left the old workspace's bearer token in place,
    // to be sent to the new server with the next request.
    test('moving to another workspace ends the session first', () async {
      final serverConfig = ServerConfig(store: store);
      final tenantContext = TenantContext(store: store);
      await serverConfig.save(
        domain: 'https://globex.example.com',
        subdomainMode: false,
      );
      await tenantContext.remember('globex');
      repository = WorkspaceRepository(
        serverConfig: serverConfig,
        tenantContext: tenantContext,
        api: WorkspaceApiService(probe: (url, headers) => answer.future),
      );
      String? workspaceWhenEnded;
      var ended = 0;
      setup.onClose();
      setup = SetupController(
        repository: repository,
        endSession: () async {
          ended++;
          workspaceWhenEnded = repository.workspace;
        },
      )..onInit();
      setup.domainController.text = 'hrms.example.com';
      setup.workspaceController.text = 'acme';

      final checked = setup.check();
      answer.complete(found);
      await checked;
      await setup.proceed();

      expect(ended, 1);
      // Ended while the old workspace was still the configured one, so the
      // sign-out reaches the server that issued the token.
      expect(workspaceWhenEnded, 'globex');
      expect(repository.workspace, 'acme');
    });

    test('confirming the same workspace again keeps the session', () async {
      var ended = 0;
      setup.onClose();
      setup = SetupController(
        repository: repository,
        endSession: () async => ended++,
      )..onInit();
      setup.domainController.text = 'hrms.example.com';
      setup.workspaceController.text = 'acme';
      var checked = setup.check();
      answer.complete(found);
      await checked;
      await setup.proceed();
      expect(ended, 1, reason: 'first setup: nothing to keep, nothing lost');

      ended = 0;
      answer = Completer();
      setup.workspaceController.text = 'acme ';
      setup.workspaceController.text = 'acme';
      checked = setup.check();
      answer.complete(found);
      await checked;
      await setup.proceed();

      expect(ended, 0);
    });

    // SETUP-02. Auto-capitalisation typed "Acme", refused before the
    // lower-casing that the save applies anyway.
    test('a capitalised workspace is accepted as the label it is', () {
      expect(setup.validateWorkspace('Acme'), isNull);
      expect(setup.validateWorkspace(' acme '), isNull);
    });

    // SETUP-03. An answer for values since edited must not land.
    test('an answer for values since edited is dropped', () async {
      final checked = setup.check();
      setup.workspaceController.text = 'acne';
      answer.complete(found);
      await checked;

      expect(setup.confirmedName.value, isNull);
      expect(repository.isConfigured, isFalse);
    });
  });
}
