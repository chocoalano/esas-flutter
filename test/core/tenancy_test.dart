import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is unresolved until somebody has been asked', () async {
    final context = TenantContext(store: InMemorySecureStore());

    await context.restore();

    // The compiled-in TENANT seed is empty in a plain test build.
    expect(context.tenant, isNull);
    expect(context.isResolved, isFalse);
  });

  test('remembers a workspace across restores', () async {
    final store = InMemorySecureStore();

    await TenantContext(store: store).remember('acme');

    final next = TenantContext(store: store);
    await next.restore();

    expect(next.tenant, 'acme');
    expect(next.isResolved, isTrue);
  });

  test('clearing is moving the handset, not signing out', () async {
    // Logout ends a credential. It does not move the handset to another
    // company, and asking for the workspace again at every login is friction
    // with no security value (ADR-0005 §3).
    final store = InMemorySecureStore();
    final context = TenantContext(store: store);
    await context.remember('acme');

    await context.clear();

    expect(context.tenant, isNull);
    expect(await store.read('esas.tenant'), isNull);
  });
}
