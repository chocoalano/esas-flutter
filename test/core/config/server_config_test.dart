import 'package:esas/core/config/env.dart';
import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalise', () {
    test('keeps an explicit scheme', () {
      expect(
        ServerConfig.normalise('https://hrms.example.com'),
        'https://hrms.example.com',
      );
      expect(
        ServerConfig.normalise('http://hrms.example.com'),
        'http://hrms.example.com',
      );
    });

    test('assumes https for a bare public name', () {
      // The guess that is wrong to make is the one that sends a password in
      // the clear.
      expect(
        ServerConfig.normalise('hrms.example.com'),
        'https://hrms.example.com',
      );
    });

    test('assumes http for an address or a reserved suffix', () {
      // No public CA issues for these, so https would fail with a message about
      // the network rather than about the scheme nobody chose.
      expect(
        ServerConfig.normalise('172.16.3.56:8000'),
        'http://172.16.3.56:8000',
      );
      expect(ServerConfig.normalise('esas.test:8000'), 'http://esas.test:8000');
      expect(ServerConfig.normalise('10.0.2.2:8000'), 'http://10.0.2.2:8000');
    });

    test('keeps the port and discards any path', () {
      // `/api` is the app's to add; an address carrying it would be requested
      // at `/api/api`.
      expect(
        ServerConfig.normalise('https://hrms.example.com:9443/api'),
        'https://hrms.example.com:9443',
      );
      expect(
        ServerConfig.normalise('https://hrms.example.com/'),
        'https://hrms.example.com',
      );
    });

    test('lowercases the host', () {
      expect(
        ServerConfig.normalise('HRMS.Example.COM'),
        'https://hrms.example.com',
      );
    });

    test('rejects what is not an address', () {
      expect(ServerConfig.normalise(null), isNull);
      expect(ServerConfig.normalise(''), isNull);
      expect(ServerConfig.normalise('   '), isNull);
      expect(ServerConfig.normalise('ftp://hrms.example.com'), isNull);
    });
  });

  group('isIpLiteral', () {
    test('recognises IPv4 and IPv6', () {
      expect(ServerConfig.isIpLiteral('172.16.3.56'), isTrue);
      expect(ServerConfig.isIpLiteral('10.0.2.2'), isTrue);
      expect(ServerConfig.isIpLiteral('::1'), isTrue);
    });

    test('rejects names, including ones that merely look numeric', () {
      expect(ServerConfig.isIpLiteral('hrms.example.com'), isFalse);
      expect(ServerConfig.isIpLiteral('999.1.1.1'), isFalse);
      expect(ServerConfig.isIpLiteral('1.2.3'), isFalse);
    });
  });

  group('isDevelopmentHost', () {
    test('is true for addresses and reserved suffixes', () {
      expect(ServerConfig.isDevelopmentHost('172.16.3.56'), isTrue);
      expect(ServerConfig.isDevelopmentHost('esas.test'), isTrue);
      expect(ServerConfig.isDevelopmentHost('acme.esas.test'), isTrue);
      expect(ServerConfig.isDevelopmentHost('localhost'), isTrue);
    });

    test('is true for an address embedded in a wildcard-DNS name', () {
      expect(ServerConfig.isDevelopmentHost('acme.10.0.2.2.nip.io'), isTrue);
    });

    test('is false for a routable name', () {
      expect(ServerConfig.isDevelopmentHost('hrms.example.com'), isFalse);
      expect(ServerConfig.isDevelopmentHost(''), isFalse);
    });
  });

  group('isValidWorkspace', () {
    test('accepts a DNS label', () {
      expect(ServerConfig.isValidWorkspace('acme'), isTrue);
      expect(ServerConfig.isValidWorkspace('sinergi-abadi'), isTrue);
      expect(ServerConfig.isValidWorkspace('a1'), isTrue);
    });

    test('rejects what the server could not resolve', () {
      expect(ServerConfig.isValidWorkspace(null), isFalse);
      expect(ServerConfig.isValidWorkspace(''), isFalse);
      expect(ServerConfig.isValidWorkspace('Acme'), isFalse);
      expect(ServerConfig.isValidWorkspace('acme corp'), isFalse);
      expect(ServerConfig.isValidWorkspace('-acme'), isFalse);
      expect(ServerConfig.isValidWorkspace('acme-'), isFalse);
      expect(
        ServerConfig.isValidWorkspace('https://acme.example.com'),
        isFalse,
      );
      expect(ServerConfig.isValidWorkspace('a' * 64), isFalse);
    });
  });

  group('originFor', () {
    late ServerConfig config;

    setUp(() => config = ServerConfig(store: InMemorySecureStore()));

    test('puts the workspace in front of the host in subdomain mode', () async {
      await config.save(
        domain: 'https://hrms.example.com',
        subdomainMode: true,
      );

      expect(config.originFor('acme'), 'https://acme.hrms.example.com');
    });

    test('keeps the port out of the hostname', () async {
      await config.save(
        domain: 'https://hrms.example.com:9443',
        subdomainMode: true,
      );

      expect(config.originFor('acme'), 'https://acme.hrms.example.com:9443');
    });

    test('leaves the host alone in single-host mode', () async {
      await config.save(
        domain: 'https://hrms.example.com',
        subdomainMode: false,
      );

      expect(config.originFor('acme'), 'https://hrms.example.com');
    });

    test('never puts a workspace in front of an IP', () async {
      // `acme.10.0.2.2` resolves to nothing. Checked here as well as on the
      // setup screen, so a handset configured before this rule existed still
      // reaches the server.
      await config.save(domain: 'http://10.0.2.2:8000', subdomainMode: true);

      expect(config.originFor('acme'), 'http://10.0.2.2:8000');
    });

    test('returns the bare domain when no workspace is known yet', () async {
      // The setup screen has to reach the server before it knows which
      // workspace it is checking.
      await config.save(
        domain: 'https://hrms.example.com',
        subdomainMode: true,
      );

      expect(config.originFor(null), 'https://hrms.example.com');
      expect(config.originFor('  '), 'https://hrms.example.com');
    });

    test('is null until the handset is configured', () {
      expect(config.originFor('acme'), isNull);
      expect(config.isConfigured, isFalse);
    });

    test('apiRootFor appends the API prefix', () async {
      await config.save(
        domain: 'https://hrms.example.com',
        subdomainMode: true,
      );

      // `/api/v1` — the surface tenancy-app actually serves, and the same one
      // the attendance kiosk runs on. `/api/selfservice` was a candidate
      // namespace that never existed on any server, and a second one would have
      // meant a second copy of tenant identification, the Sanctum guard and the
      // rate limiters. See ADR-0006 and ADR-0007.
      expect(config.apiRootFor('acme'), 'https://acme.hrms.example.com/api/v1');
    });
  });

  group('restore', () {
    test('a build with no compiled-in address is NOT configured', () async {
      // No deployment is compiled into this repository: the server address is a
      // setting under ADR-0005, not a property of the APK. So a handset that has
      // never been configured has no address, and the app opens on the setup
      // screen and asks.
      //
      // The alternative — shipping a plausible-looking host nobody runs — would
      // leave the app "configured" and failing at every request, with no setup
      // screen to fix it from.
      final config = ServerConfig(store: InMemorySecureStore());

      await config.restore();

      expect(Env.apiBaseUrl, isEmpty);
      expect(config.domain, isNull);
      expect(config.isConfigured, isFalse);
    });

    test('a build compiled FOR a deployment opens on it', () async {
      // The `--dart-define` path, which is how a build for a known deployment is
      // made. Exercised through `normalise` rather than by rebuilding with a
      // define, because that is the whole of what `restore` does with it.
      const compiledIn = 'https://hrms.example.com:9443';

      expect(ServerConfig.normalise(compiledIn), compiledIn);
      expect(ServerConfig.normalise(compiledIn), isNotNull);
    });

    test('prefers what was stored', () async {
      final store = InMemorySecureStore({
        'esas.server_domain': 'https://hrms.example.com',
        'esas.server_subdomain_mode': 'false',
      });
      final config = ServerConfig(store: store);

      await config.restore();

      expect(config.domain, 'https://hrms.example.com');
      expect(config.subdomainMode, isFalse);
    });

    test('an unreadable keystore reads as null rather than throwing', () async {
      // KeychainSecureStore against an absent platform channel, which is what a
      // wiped key or a misbehaving OEM build looks like from Dart. The contract
      // is that this reads as null rather than throwing on the first frame —
      // and the handset then asks for its server, which is recoverable, instead
      // of crashing before it can draw anything.
      TestWidgetsFlutterBinding.ensureInitialized();

      final config = ServerConfig(store: KeychainSecureStore());

      await config.restore();

      expect(config.domain, ServerConfig.normalise(Env.apiBaseUrl));
      expect(config.isConfigured, isFalse);
    });
  });

  group('isPlausibleHost', () {
    test('rejects a host that could never resolve', () {
      // Uri.tryParse percent-encodes rather than rejecting, so without this
      // check a typo is stored as a server address.
      expect(ServerConfig.isPlausibleHost('not%20an%20address'), isFalse);
      expect(ServerConfig.isPlausibleHost(''), isFalse);
      expect(ServerConfig.isPlausibleHost('-acme.example.com'), isFalse);
      expect(ServerConfig.isPlausibleHost('acme..example.com'), isFalse);
    });

    test('accepts names and addresses', () {
      expect(ServerConfig.isPlausibleHost('hrms.example.com'), isTrue);
      expect(ServerConfig.isPlausibleHost('localhost'), isTrue);
      expect(ServerConfig.isPlausibleHost('172.16.3.56'), isTrue);
    });
  });

  group('save', () {
    test('rejects an address that is not one', () {
      final config = ServerConfig(store: InMemorySecureStore());

      expect(
        () => config.save(domain: 'not an address', subdomainMode: true),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('normalise refuses a typed-in phrase outright', () {
      expect(ServerConfig.normalise('not an address'), isNull);
      expect(ServerConfig.normalise('hrms example com'), isNull);
    });
  });
}
