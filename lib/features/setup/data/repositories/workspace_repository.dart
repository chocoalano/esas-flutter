import '../../../../core/config/env.dart';
import '../../../../core/config/server_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/tenancy/tenant_context.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/workspace.dart';
import '../services/workspace_api_service.dart';

/// Which server, and which company on it.
///
/// The two are checked **together and before anybody signs in**, because a
/// sign-in cannot tell them apart: a wrong address, a wrong workspace and a
/// wrong password all arrive as one refusal, and the person holding the phone
/// then retypes the password — the one thing that was right.
///
/// **Nothing is stored until the server has confirmed it.** A stored address
/// that was never reached is a handset that looks set up and is not, and it
/// fails on somebody's first morning rather than during setup.
class WorkspaceRepository {
  WorkspaceRepository({
    required ServerConfig serverConfig,
    required TenantContext tenantContext,
    WorkspaceApiService? api,
  }) : _serverConfig = serverConfig,
       _tenantContext = tenantContext,
       _api = api ?? WorkspaceApiService();

  final ServerConfig _serverConfig;
  final TenantContext _tenantContext;
  final WorkspaceApiService _api;

  /// Whether this handset knows both halves of where it belongs.
  ///
  /// The address alone is not enough: a build ships with one compiled in, so
  /// `ServerConfig.isConfigured` is true from the first launch. The workspace is
  /// what nobody can guess for the employee, and it is what the setup screen
  /// exists to ask (ADR-0005 §4).
  bool get isConfigured =>
      _serverConfig.isConfigured && _tenantContext.isResolved;

  String? get domain => _serverConfig.domain;

  bool get subdomainMode => _serverConfig.subdomainMode;

  String? get workspace => _tenantContext.tenant;

  AppEnvironment get appEnvironment => _serverConfig.appEnvironment;

  String get environmentLabel => _serverConfig.environmentLabel;

  String? get environment => _serverConfig.environment;

  /// Point this handset at [domain]/[workspace], if the server agrees it exists.
  ///
  /// Order matters and is the opposite of the obvious one: the candidate is
  /// *composed*, then asked, and only then saved. Assigning it onto the live
  /// configuration first — as the sibling app does — leaves a handset pointed at
  /// an address nothing has answered for as long as the request takes, and
  /// permanently if the process dies in between.
  /// Ask the server whether this address and workspace exist — and store
  /// nothing (SETUP-01). Saving at this point committed the handset before
  /// the screen had asked "is this your company?"; a typo that reached
  /// another real workspace locked it there.
  Future<WorkspaceCandidate> probe({
    required String domain,
    required String workspace,
    required bool subdomainMode,
  }) async {
    final address = ServerConfig.normalise(domain);

    if (address == null) {
      throw const ApiException(
        'Alamat server tidak dikenali. Contoh: hrms.perusahaan.co.id',
        code: 'invalid_address',
      );
    }

    final code = workspace.trim().toLowerCase();

    if (!ServerConfig.isValidWorkspace(code)) {
      throw const ApiException(
        'Kode workspace hanya boleh huruf kecil, angka dan tanda hubung. '
        'Contoh: acme',
        code: 'invalid_workspace',
      );
    }

    // Non-null: `normalise` already accepted the address, and `originOf`
    // normalises again rather than trusting its caller.
    final origin = ServerConfig.originOf(
      domain: address,
      tenant: code,
      subdomainMode: subdomainMode,
    )!;

    final found = await _api.check(origin: origin, workspace: code);

    return WorkspaceCandidate(
      workspace: found,
      address: address,
      code: code,
      subdomainMode: subdomainMode,
    );
  }

  /// Store a workspace the person has confirmed is theirs (SETUP-01).
  /// Whether [candidate] is the workspace this handset is already set to.
  bool isCurrent(WorkspaceCandidate candidate) =>
      _serverConfig.domain == candidate.address &&
      _tenantContext.tenant == candidate.code &&
      _serverConfig.subdomainMode == candidate.subdomainMode;

  Future<void> adopt(
    WorkspaceCandidate candidate, {
    String? environment,
  }) async {
    final env = environment ?? candidate.workspace.environment;
    await _serverConfig.save(
      domain: candidate.address,
      subdomainMode: candidate.subdomainMode,
      environment: env,
    );
    await _tenantContext.remember(candidate.code);

    AppLogger.info(
      'Workspace configured: ${candidate.workspace.subdomain} at '
      '${candidate.address} [${env ?? 'auto'}].',
    );
  }

  /// Probe and store in one step, for a caller with nobody to ask.
  Future<Workspace> connect({
    required String domain,
    required String workspace,
    required bool subdomainMode,
  }) async {
    final candidate = await probe(
      domain: domain,
      workspace: workspace,
      subdomainMode: subdomainMode,
    );

    await adopt(candidate);

    return candidate.workspace;
  }

  /// Forget the workspace, so this handset can be handed to another company.
  ///
  /// Deliberately **not** part of signing out. Logging out ends a credential; an
  /// employee who logs out still works where they worked, and being asked for
  /// the workspace at every login is friction with no security value (ADR-0005
  /// §3). The address is kept: the platform is the same one.
  Future<void> forget() async {
    await _tenantContext.clear();

    AppLogger.info('Workspace forgotten; this handset needs setting up again.');
  }
}

/// A workspace the server confirmed exists, not yet adopted by this handset.
class WorkspaceCandidate {
  const WorkspaceCandidate({
    required this.workspace,
    required this.address,
    required this.code,
    required this.subdomainMode,
  });

  final Workspace workspace;
  final String address;
  final String code;
  final bool subdomainMode;
}
