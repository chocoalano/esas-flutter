import '../storage/secure_store.dart';
import 'env.dart';

/// Where this handset looks for its workspace.
///
/// Adapted from the sibling app `esas_attendance`, which solved this first. The
/// normalisation and host rules below encode real deployment lessons — see the
/// doc comments on each — and are kept rather than rewritten so both ESAS
/// Flutter apps resolve a workspace the same way.
///
/// Two things are stored, and they answer different questions:
///
///   [domain]         the platform's address — `hrms.example.com`. The same for
///                    every company hosted there.
///   `TenantContext.tenant`  which company — `acme`. Different per handset, and
///                    the thing the employee is told by HR.
///
/// How the two combine is [subdomainMode]:
///
///   **Subdomain** (the default) reaches `acme.hrms.example.com`. The workspace
///   is in the host, which is how the web application identifies a tenant, so a
///   handset and a browser resolve the same workspace by the same name. Needs a
///   wildcard DNS record and a wildcard certificate.
///
///   **Single host** reaches `hrms.example.com` and names the workspace in the
///   `X-Tenant` header instead. For a deployment with no wildcard certificate,
///   and for an emulator, where `acme.10.0.2.2` resolves to nothing.
///
/// The header is sent either way, so which one the server reads cannot change
/// the answer.
class ServerConfig {
  ServerConfig({SecureStore? store}) : _store = store ?? KeychainSecureStore();

  final SecureStore _store;

  static const _domainKey = 'esas.server_domain';
  static const _subdomainModeKey = 'esas.server_subdomain_mode';

  /// The platform address, normalised to `scheme://host[:port]` with no
  /// workspace on the front. Null until this handset has been configured.
  String? domain;

  /// Whether the workspace is a subdomain of [domain] rather than a header.
  bool subdomainMode = true;

  bool get isConfigured => domain != null;

  /// Whether the configured address is encrypted.
  ///
  /// Read from the stored address rather than from the build: a build compiled
  /// against an HTTPS default is not evidence that nobody then pointed it at
  /// plain HTTP.
  bool get isSecure => (domain ?? '').startsWith('https://');

  /// Read what is stored. Called once, from bootstrap, before the first frame.
  Future<void> restore() async {
    domain = await _store.read(_domainKey) ?? normalise(Env.apiBaseUrl);
    subdomainMode =
        (await _store.read(_subdomainModeKey) ?? _defaultMode) == 'true';
  }

  Future<void> save({
    required String domain,
    required bool subdomainMode,
  }) async {
    final normalised = normalise(domain);

    if (normalised == null) {
      throw ArgumentError.value(domain, 'domain', 'not an address');
    }

    this.domain = normalised;
    this.subdomainMode = subdomainMode;

    await _store.write(_domainKey, normalised);
    await _store.write(_subdomainModeKey, subdomainMode.toString());
  }

  /// The origin a request for [tenant] goes to, or null when this handset has
  /// not been configured.
  ///
  /// In subdomain mode with no workspace yet, the bare domain is returned rather
  /// than nothing: the setup screen has to reach the server before it knows
  /// which workspace it is checking.
  String? originFor(String? tenant) {
    final base = domain;

    return base == null
        ? null
        : originOf(domain: base, tenant: tenant, subdomainMode: subdomainMode);
  }

  /// The same composition, as a pure function of values rather than of stored
  /// state.
  ///
  /// Exists for the setup screen, which has to build the address it is about to
  /// *test* — one nobody has agreed to store yet. The sibling app solves this by
  /// assigning the candidate onto the live config, making the request, and
  /// putting the old values back if it failed; that works, but it means a
  /// handset is briefly pointed at an address that has never answered, and a
  /// crash in between leaves it there. Composing the candidate without touching
  /// the setting removes the window entirely.
  static String? originOf({
    required String domain,
    required String? tenant,
    required bool subdomainMode,
  }) {
    final normalised = normalise(domain);

    if (normalised == null) {
      return null;
    }

    final workspace = (tenant ?? '').trim();

    // Rebuilt through Uri rather than by string surgery, so a port, a path or a
    // trailing slash on the stored address cannot end up inside the hostname.
    final uri = Uri.parse(normalised);

    // An address that is an IP can never carry a workspace on its front:
    // `acme.172.16.2.233` is not a hostname anything resolves.
    if (!subdomainMode || workspace.isEmpty || isIpLiteral(uri.host)) {
      return normalised;
    }

    return uri.replace(host: '$workspace.${uri.host}').toString();
  }

  /// The full API root a request for [tenant] is built on.
  String? apiRootFor(String? tenant) {
    final origin = originFor(tenant);

    return origin == null ? null : '$origin${Env.apiPrefix}';
  }

  /// Turn what somebody typed into `scheme://host[:port]`, or null if it is not
  /// an address at all.
  ///
  /// Accepts `hrms.example.com`, `https://hrms.example.com`, and
  /// `http://10.0.2.2:8000/` alike.
  ///
  /// A bare *name* is assumed HTTPS: the guess that is wrong to make is the one
  /// that sends an employee's password in the clear. A bare address that can
  /// only be a development server is assumed HTTP — no public certificate
  /// authority issues for a private address or a reserved suffix, so
  /// `172.16.3.56:8000` and `esas.test:8000` are development servers whatever
  /// else is true of them.
  ///
  /// Any path is discarded. `/api` is this app's to add, and an address with it
  /// already on the end would otherwise be requested at `/api/api`.
  static String? normalise(String? input) {
    var value = (input ?? '').trim();

    if (value.isEmpty) {
      return null;
    }

    final hadScheme = value.contains('://');

    // A provisional scheme, only so there is a host to parse out. The real one
    // is chosen below, once the host is known.
    if (!hadScheme) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);

    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    // `Uri.tryParse` does not validate a host, it percent-encodes whatever it
    // finds: `http://not an address` parses with host `not%20an%20address` and
    // no error at all. Without this check a typo on the setup screen is saved as
    // a server address and then fails as an unresolvable name, which reads to
    // the person as "the server is down" rather than "that is not an address".
    if (!isPlausibleHost(uri.host)) {
      return null;
    }

    final scheme = hadScheme
        ? uri.scheme
        : (isDevelopmentHost(uri.host) ? 'http' : 'https');

    final port = uri.hasPort ? ':${uri.port}' : '';

    return '$scheme://${uri.host.toLowerCase()}$port';
  }

  /// Whether a host could be resolved at all — a DNS name or an IP literal.
  ///
  /// Not a check that the host *exists*; a check that it is the kind of string
  /// that could. Labels of letters, digits and hyphens, separated by dots, with
  /// no label starting or ending in a hyphen.
  static bool isPlausibleHost(String host) {
    if (host.isEmpty) {
      return false;
    }

    if (isIpLiteral(host)) {
      return true;
    }

    // A percent-encoded octet is proof something was in there that a hostname
    // cannot contain.
    if (host.contains('%')) {
      return false;
    }

    final label = RegExp(
      r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$',
      caseSensitive: false,
    );

    return host
        .split('.')
        .every(
          (part) =>
              part.isNotEmpty && part.length <= 63 && label.hasMatch(part),
        );
  }

  /// Whether a host is an IP address rather than a name.
  ///
  /// Two things turn on this, and both are the same fact: an IP identifies a
  /// machine, and a workspace is a name in front of one.
  static bool isIpLiteral(String host) {
    if (host.contains(':')) {
      // An IPv6 literal, which arrives bracketed in a URL.
      return true;
    }

    return _isDottedQuad(host.split('.'));
  }

  /// Top-level domains that can only ever name something on this network.
  ///
  /// `.test`, `.localhost`, `.invalid` and `.example` are reserved for exactly
  /// this by RFC 6761; `.local` is mDNS; `.internal` and `.home.arpa` are the
  /// private-network names. No public certificate authority will issue for any
  /// of them, which makes this a fact rather than a guess about naming taste.
  static const _developmentTlds = {
    'test',
    'localhost',
    'local',
    'internal',
    'invalid',
    'example',
    'arpa',
  };

  /// Whether a host can only be a development or private-network server.
  ///
  /// Distinct from [isIpLiteral], which asks whether the host *is* an address
  /// and therefore cannot take a workspace on its front. `esas.test` can.
  static bool isDevelopmentHost(String host) {
    if (isIpLiteral(host)) {
      return true;
    }

    final labels = host.split('.');

    if (_developmentTlds.contains(labels.last.toLowerCase())) {
      return true;
    }

    // An address embedded in a name, as the wildcard-DNS services produce.
    for (var i = 0; i + 4 <= labels.length; i++) {
      if (_isDottedQuad(labels.sublist(i, i + 4))) {
        return true;
      }
    }

    return false;
  }

  static bool _isDottedQuad(List<String> labels) {
    return labels.length == 4 &&
        labels.every((label) {
          final octet = int.tryParse(label);

          return octet != null && octet >= 0 && octet <= 255;
        });
  }

  /// Whether a workspace code is a DNS label, which is what the server resolves
  /// a tenant by. Checked so a typed-in space or a pasted URL is caught on the
  /// setup screen rather than as a 404 with no explanation.
  static bool isValidWorkspace(String? input) {
    final value = (input ?? '').trim();

    if (value.isEmpty || value.length > 63) {
      return false;
    }

    return RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$').hasMatch(value);
  }

  /// The mode a build with no stored preference starts in.
  ///
  /// A compiled-in address that is bare or numeric cannot carry a workspace on
  /// its front, so such a build starts in single-host mode rather than opening
  /// on a setting that could not work.
  static String get _defaultMode {
    final host = Uri.tryParse(normalise(Env.apiBaseUrl) ?? '')?.host ?? '';

    return (host.split('.').length < 2 || isIpLiteral(host)) ? 'false' : 'true';
  }
}
