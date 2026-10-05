import '../config/env.dart';
import '../storage/secure_store.dart';
import '../storage/storage_keys.dart';

/// Which workspace this handset belongs to.
///
/// Held separately from the session because the two have different lifetimes.
/// Signing out ends a *credential*; it does not move the handset to another
/// company. An employee who logs out still works where they worked, and asking
/// for the workspace again at every login is friction with no security value —
/// so [clear] is a deliberate "move this handset", not part of logout. See
/// ADR-0005 §3.
///
/// [tenant] is a synchronous getter for the same reason [TokenStorage.token] is:
/// a request modifier cannot await.
class TenantContext {
  TenantContext({SecureStore? store}) : _store = store ?? KeychainSecureStore();

  final SecureStore _store;

  String? _tenant;

  /// The workspace code — `acme`. Null until somebody has been asked for it.
  String? get tenant => _tenant;

  bool get isResolved => _tenant != null && _tenant!.isNotEmpty;

  /// Read what is stored, falling back to the compiled-in seed so a build made
  /// for a known deployment opens ready to use.
  Future<void> restore() async {
    _tenant =
        await _store.read(StorageKeys.secure.tenant) ??
        (Env.defaultTenant.isEmpty ? null : Env.defaultTenant);
  }

  Future<void> remember(String tenant) async {
    _tenant = tenant;

    await _store.write(StorageKeys.secure.tenant, tenant);
  }

  /// Forget the workspace. For a handset being moved to another company —
  /// never as part of signing out.
  Future<void> clear() async {
    _tenant = null;

    await _store.delete(StorageKeys.secure.tenant);
  }
}
