import 'package:esas/core/config/env.dart';
import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/features/setup/data/repositories/workspace_repository.dart';
import 'package:esas/features/setup/data/services/workspace_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the probe was asked, and answers with what a test wants.
class _FakeProbe {
  _FakeProbe({this.body});

  int? status = 200;
  Object? body;
  Object? throws;

  Uri? url;
  Map<String, String>? headers;
  int calls = 0;

  Future<({int? status, Object? body})> call(
    Uri url,
    Map<String, String> headers,
  ) async {
    calls++;
    this.url = url;
    this.headers = headers;

    if (throws != null) {
      throw throws!;
    }

    return (status: status, body: body);
  }
}

void main() {
  late InMemorySecureStore store;
  late ServerConfig serverConfig;
  late TenantContext tenantContext;
  late _FakeProbe probe;
  late WorkspaceRepository repository;

  setUp(() async {
    store = InMemorySecureStore();
    serverConfig = ServerConfig(store: store);
    tenantContext = TenantContext(store: store);

    await serverConfig.restore();
    await tenantContext.restore();

    probe = _FakeProbe(
      body: {
        'subdomain': 'acme',
        'name': 'PT Acme Nusantara',
        'api_version': 'v1',
      },
    );

    repository = WorkspaceRepository(
      serverConfig: serverConfig,
      tenantContext: tenantContext,
      api: WorkspaceApiService(probe: probe.call),
    );
  });

  group('what the probe is asked', () {
    test('asks the platform surface, not this client\'s own prefix', () async {
      await repository.connect(
        domain: 'hrms.example.com',
        workspace: 'acme',
        subdomainMode: true,
      );

      // `/api/v1/workspace` exists on tenancy-app today; `Env.apiPrefix` is
      // still waiting on ADR-0007 and may not answer this at all.
      expect(probe.url!.path, '${Env.platformApiPrefix}/workspace');
    });

    test('puts the workspace in the host when subdomain mode is on', () async {
      await repository.connect(
        domain: 'hrms.example.com',
        workspace: 'acme',
        subdomainMode: true,
      );

      expect(probe.url!.origin, 'https://acme.hrms.example.com');
    });

    test('leaves the host alone in single-host mode', () async {
      await repository.connect(
        domain: 'hrms.example.com',
        workspace: 'acme',
        subdomainMode: false,
      );

      expect(probe.url!.origin, 'https://hrms.example.com');
    });

    test('names the workspace in X-Tenant in both deployment modes', () async {
      // The header is what a single-host deployment resolves the tenant by, and
      // it agrees with the host in subdomain mode — so which one the server
      // reads cannot change the answer (ADR-0005).
      for (final subdomainMode in [true, false]) {
        await repository.connect(
          domain: 'hrms.example.com',
          workspace: 'acme',
          subdomainMode: subdomainMode,
        );

        expect(
          probe.headers!['X-Tenant'],
          'acme',
          reason: 'subdomainMode: $subdomainMode',
        );
      }
    });

    test(
      'is unauthenticated — setup happens before there is an account',
      () async {
        await repository.connect(
          domain: 'hrms.example.com',
          workspace: 'acme',
          subdomainMode: true,
        );

        // A token is what signing in produces, not what checking an address
        // requires — and at this point there is none to send anyway.
        expect(probe.headers!.containsKey('Authorization'), isFalse);
      },
    );
  });

  group('nothing is stored until the server confirms', () {
    test('a confirmed workspace is saved, and named back', () async {
      final found = await repository.connect(
        domain: 'hrms.example.com',
        workspace: 'ACME ',
        subdomainMode: true,
      );

      expect(found.name, 'PT Acme Nusantara');
      expect(serverConfig.domain, 'https://hrms.example.com');
      expect(serverConfig.subdomainMode, isTrue);
      // Lower-cased and trimmed: a workspace is a DNS label, and `ACME ` is the
      // same company as `acme`.
      expect(tenantContext.tenant, 'acme');
      expect(repository.isConfigured, isTrue);
    });

    test('a refusal leaves the handset exactly as it was', () async {
      probe.status = 404;
      probe.body = {'message': 'Not Found'};

      await expectLater(
        repository.connect(
          domain: 'hrms.example.com',
          workspace: 'ghost',
          subdomainMode: true,
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );

      expect(tenantContext.tenant, isNull);
      expect(await store.read('esas.tenant'), isNull);
    });

    test('a dead socket is a transport failure, not a refusal', () async {
      probe.throws = const SocketExceptionStub();

      await expectLater(
        repository.connect(
          domain: 'hrms.example.com',
          workspace: 'acme',
          subdomainMode: true,
        ),
        throwsA(isA<ApiException>()),
      );

      expect(tenantContext.tenant, isNull);
    });
  });

  group('what is refused before a request is even made', () {
    test('an address that is not an address', () async {
      await expectLater(
        repository.connect(
          domain: 'not an address',
          workspace: 'acme',
          subdomainMode: true,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_address'),
        ),
      );

      expect(probe.calls, 0);
    });

    test('a workspace that is not a DNS label', () async {
      await expectLater(
        repository.connect(
          domain: 'hrms.example.com',
          workspace: 'acme corp',
          subdomainMode: true,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'invalid_workspace',
          ),
        ),
      );

      expect(probe.calls, 0);
    });
  });

  group('forgetting', () {
    test('clears the workspace and keeps the address', () async {
      await repository.connect(
        domain: 'hrms.example.com',
        workspace: 'acme',
        subdomainMode: true,
      );

      await repository.forget();

      expect(tenantContext.tenant, isNull);
      expect(repository.isConfigured, isFalse);
      // The platform did not move; only this handset's company did.
      expect(serverConfig.domain, 'https://hrms.example.com');
    });
  });

  group('the answer', () {
    test(
      'falls back to what was typed when the server names nothing',
      () async {
        probe.body = const <String, dynamic>{};

        final found = await repository.connect(
          domain: 'hrms.example.com',
          workspace: 'acme',
          subdomainMode: true,
        );

        // A workspace that confirmed but has no display name still confirmed.
        expect(found.name, 'acme');
        expect(found.subdomain, 'acme');
      },
    );

    test('a body that is not JSON does not mask the status', () async {
      // A wrong address often answers with somebody else's HTML.
      probe.status = 502;
      probe.body = null;

      await expectLater(
        repository.connect(
          domain: 'hrms.example.com',
          workspace: 'acme',
          subdomainMode: true,
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 502)),
      );
    });
  });
}

/// Stands in for a `SocketException` without importing `dart:io` into a test
/// that has no other use for it.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
