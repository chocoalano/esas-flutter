import 'package:esas/core/network/auth_interceptor.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The auth-injection matrix.
///
/// Written before `ApiProvider` is retired, because porting its rules is the
/// most behaviour-sensitive change in the refactor (MED-02) and the rule it
/// replaces is the one that silently breaks under tenancy (TEN-02).
void main() {
  Map<String, String> headers({
    required bool authenticated,
    String? token,
    String? tenant,
    Map<String, String>? extra,
  }) => AuthInterceptor.buildHeaders(
    authenticated: authenticated,
    token: token,
    tenant: tenant,
    extra: extra,
  );

  group('Authorization', () {
    test('is attached when the call is authenticated and a token exists', () {
      expect(
        headers(authenticated: true, token: 'abc123'),
        containsPair('Authorization', 'Bearer abc123'),
      );
    });

    test('is absent when the call is explicitly unauthenticated', () {
      // Login and the setup probe. The old code expressed this as an in-band
      // `X-Bypass-Auth` header the caller set and the modifier stripped.
      expect(
        headers(authenticated: false, token: 'abc123'),
        isNot(contains('Authorization')),
      );
    });

    test('is absent when there is no token', () {
      expect(
        headers(authenticated: true, token: null),
        isNot(contains('Authorization')),
      );
      expect(
        headers(authenticated: true, token: ''),
        isNot(contains('Authorization')),
      );
    });

    test('does not depend on the host', () {
      // The rule this replaces attached the token only when the request host
      // equalled the configured base host. Under subdomain tenancy the request
      // goes to acme.hrms.example.com while the domain is hrms.example.com, so
      // the hosts differ and the token silently stopped being sent (TEN-02).
      // buildHeaders takes no host at all, which is the fix.
      final subdomain = headers(
        authenticated: true,
        token: 't',
        tenant: 'acme',
      );
      final singleHost = headers(authenticated: true, token: 't');

      expect(subdomain['Authorization'], 'Bearer t');
      expect(singleHost['Authorization'], 'Bearer t');
    });
  });

  group('X-Tenant', () {
    test('is sent whenever a workspace is known', () {
      // In subdomain mode it agrees with the host, so which one the server
      // reads cannot change the answer; in single-host mode it is the only
      // thing naming the workspace at all.
      expect(
        headers(authenticated: true, token: 't', tenant: 'acme'),
        containsPair('X-Tenant', 'acme'),
      );
    });

    test('is sent even on an unauthenticated call', () {
      // The setup probe and login both have to resolve a tenant before there is
      // any token to send.
      expect(
        headers(authenticated: false, tenant: 'acme'),
        containsPair('X-Tenant', 'acme'),
      );
    });

    test('is absent when no workspace has been chosen yet', () {
      expect(
        headers(authenticated: true, token: 't'),
        isNot(contains('X-Tenant')),
      );
      expect(
        headers(authenticated: true, token: 't', tenant: ''),
        isNot(contains('X-Tenant')),
      );
    });
  });

  group('defaults and overrides', () {
    test('Accept defaults to application/json', () {
      expect(
        headers(authenticated: false),
        containsPair('Accept', 'application/json'),
      );
    });

    test('a caller header wins over the computed default', () {
      expect(
        headers(authenticated: false, extra: {'Accept': 'text/csv'}),
        containsPair('Accept', 'text/csv'),
      );
    });

    test('no extra header can turn authentication back on', () {
      // The point of the explicit flag: auth is a property of the call, not
      // something a stray header in a reused map can flip.
      final result = headers(
        authenticated: false,
        token: 'abc123',
        extra: {'X-Bypass-Auth': 'false'},
      );

      expect(result, isNot(contains('Authorization')));
    });
  });

  group('through the interceptor', () {
    test('reads the live token and tenant', () async {
      final tenant = TenantContext(store: InMemorySecureStore());
      await tenant.remember('acme');

      final interceptor = AuthInterceptor(
        tokenStorage: InMemoryTokenStorage('live-token'),
        tenantContext: tenant,
      );

      final result = interceptor.headersFor(authenticated: true);

      expect(result['Authorization'], 'Bearer live-token');
      expect(result['X-Tenant'], 'acme');
    });

    test('reflects a token cleared mid-session', () async {
      final storage = InMemoryTokenStorage('live-token');
      final interceptor = AuthInterceptor(
        tokenStorage: storage,
        tenantContext: TenantContext(store: InMemorySecureStore()),
      );

      await storage.clear();

      expect(
        interceptor.headersFor(authenticated: true),
        isNot(contains('Authorization')),
      );
    });
  });
}
