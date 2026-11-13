import 'dart:convert';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/components/custom_bottom_navbar.dart';
import 'package:esas/core/ui/controllers/bottom_nav_controller.dart';
import 'package:esas/core/services/device_info_service.dart';
import 'package:esas/features/attendance/data/models/attendance_context.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_pages.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/data/repositories/device_proof_repository.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/auth/data/services/auth_api_service.dart';
import 'package:esas/features/auth/data/services/device_auth_api_service.dart';
import 'package:esas/features/auth/data/services/device_key_service.dart';
import 'package:esas/features/auth/presentation/routes/auth_pages.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/auth/presentation/routes/device_pages.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/data/services/home_api_service.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/features/home/presentation/widgets/today_work_card.dart';
import 'package:esas/features/notification/presentation/routes/notification_routes.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:esas/features/profile/presentation/routes/profile_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

/// AUTOMATED JOURNEY HARNESS — not device UAT.
///
/// What is real: the login screen and controller, `AuthRepository`,
/// `SessionRepository`, `HomeRepository` with the real Beranda attendance card,
/// the real `/attendance` route (middleware, device gate, `AttendanceBinding`,
/// `AttendanceView`), the real `/device/enrollment` route and controller,
/// `DeviceProofRepository`, `DeviceProofGate` and `DeviceKeyService`.
///
/// What is faked: the HTTP service layer (a stateful [FakeEsasServer] that
/// follows ADR-D §7), and the keystore behind the `esas/device_key` channel
/// ([FakeKeystore]). Beranda is a thin stand-in page that hosts the real
/// `TodayWorkCard` and the real bottom bar; the full `HomeView` needs a dozen
/// unrelated endpoints and adds nothing to these journeys.
///
/// A 401 is handled the way `InitialBinding`'s `ApiClient.onUnauthorized` does
/// it: end the session, go to the sign-in screen.

const String journeyNip = '20240113';
const String journeyPassword = 'rahasia-123';
const String journeyCode = 'ABCDE12345';
const String journeyWorkspace = 'acme';
const int journeyUserId = 7;

class _Token {
  _Token({required this.userId, required this.proven});

  final int userId;
  bool proven;
}

/// One employee account on a [FakeEsasServer].
class FakeAccount {
  FakeAccount({
    required this.id,
    required this.nip,
    required this.password,
    this.name = 'Karyawan',
  });

  final int id;
  final String nip;
  final String password;
  final String name;

  /// This account's active attendance key, or null.
  String? enrolledFingerprint;
}

/// One workspace's backend, as ADR-D §7 describes it, with faults on demand.
/// Tokens, codes, keys and proofs are per account; nothing is shared with
/// another [FakeEsasServer] (another workspace).
class FakeEsasServer {
  FakeEsasServer({
    this.proofRequired = true,
    this.enrollmentAvailable = true,
    this.workspace = journeyWorkspace,
    List<FakeAccount>? accounts,
  }) : accounts =
           accounts ??
           [
             FakeAccount(
               id: journeyUserId,
               nip: journeyNip,
               password: journeyPassword,
               name: 'Budi Santoso',
             ),
           ] {
    codes[journeyCode] = this.accounts.first.id;
  }

  bool proofRequired;
  bool enrollmentAvailable;
  final String workspace;
  final List<FakeAccount> accounts;

  /// Activation code → the account it was issued to.
  final Map<String, int> codes = {};
  final Set<String> usedCodes = {};
  final Map<String, _Token> _tokens = {};
  final Map<String, String> _challenges = {};
  int _sequence = 0;

  /// What the server actually did.
  int enrollments = 0;
  int proofs = 0;
  final List<String> enrolPublicKeys = [];

  /// Every public key an enrolment challenge was asked for, in order.
  final List<String> enrolChallengeKeys = [];

  /// Faults.
  bool dropNextEnrollBeforeApplying = false;

  /// Refusals the next challenge requests answer with, in order — a 429 at a
  /// busy shift start, a 503 while the rate limiter's store is down, a 500.
  final List<ApiException> challengeRefusals = [];

  /// Every challenge request that reached this server.
  int challengeRequests = 0;
  bool loseNextEnrollAnswerAfterApplying = false;

  /// Which token the app is sending, read the way `AuthInterceptor` reads it.
  late String? Function() bearer;

  /// `ApiClient.onUnauthorized`, as `InitialBinding` wires it.
  late Future<void> Function() onUnauthorized;

  FakeAccount account(int id) => accounts.firstWhere((a) => a.id == id);

  FakeAccount get _first => accounts.first;

  /// The first account's key — the one the single-account journeys use.
  String? get enrolledFingerprint => _first.enrolledFingerprint;
  set enrolledFingerprint(String? value) => _first.enrolledFingerprint = value;

  /// HR issues an activation code to [userId] (the first account by default).
  void issueCode(String code, {int? userId}) =>
      codes[code] = userId ?? _first.id;

  /// HR releases a phone: the account's active key is revoked.
  void hrRelease({int? userId}) =>
      account(userId ?? _first.id).enrolledFingerprint = null;

  bool knows(String? token) => _tokens.containsKey(token);

  String _issue(int userId, {bool proven = false}) {
    final token = '$workspace-token-${++_sequence}';
    _tokens[token] = _Token(userId: userId, proven: proven);
    return token;
  }

  FakeAccount _accountOf(String? token) {
    final userId = _tokens[token]?.userId;

    return userId == null ? _first : account(userId);
  }

  Map<String, dynamic> _user(FakeAccount account) => {
    'id': account.id,
    'name': account.name,
    'nip': account.nip,
    'attendance_enabled': true,
  };

  Map<String, dynamic> device(String? token) {
    final owner = _accountOf(token);
    final proven = _tokens[token]?.proven ?? false;
    final keyEnrolled = owner.enrolledFingerprint != null;
    final String? block = !proofRequired
        ? null
        : !keyEnrolled
        ? 'DEVICE_NOT_ENROLLED'
        : proven
        ? null
        : 'DEVICE_PROOF_REQUIRED';

    return {
      'id': 'dev-1',
      'is_registered_device': keyEnrolled || !proofRequired,
      'can_record_attendance': block == null,
      'proof_required': proofRequired,
      'enrollment_available': enrollmentAvailable,
      'key_enrolled': keyEnrolled,
      'key_fingerprint': owner.enrolledFingerprint,
      'proof_valid_until': proven
          ? DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 10))
                .toIso8601String()
          : null,
      'attendance_block': block,
    };
  }

  Map<String, dynamic> _loginShape(String token, {List<String>? abilities}) => {
    'token': token,
    'user': _user(_accountOf(token)),
    'abilities': abilities ?? const ['profile'],
    'device': device(token),
  };

  Future<String> _caller() async {
    final token = bearer();

    if (token == null || !_tokens.containsKey(token)) {
      await onUnauthorized();
      throw const ApiException('Unauthenticated.', status: 401);
    }

    return token;
  }

  static const _timeout = ApiException(
    'Koneksi terlalu lama. Silakan coba lagi nanti.',
    code: 'timeout',
  );

  // ── auth ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final match = accounts.where(
      (a) => a.nip == identifier && a.password == password,
    );

    if (match.isEmpty) {
      throw const ApiException('NIP/Email atau kata sandi salah.', status: 401);
    }

    return _loginShape(_issue(match.first.id));
  }

  Future<Map<String, dynamic>> logout() async {
    _tokens.remove(bearer());
    return const {};
  }

  Future<Map<String, dynamic>> forgotPassword(String identifier) async => {
    'message':
        'Jika akun terdaftar, instruksi reset kata sandi telah dikirim ke '
        'email terdaftar.',
  };

  // ── device (ADR-D §7) ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> challenge(
    String purpose,
    String? publicKey,
  ) async {
    final token = await _caller();
    final owner = _accountOf(token);
    challengeRequests++;

    if (challengeRefusals.isNotEmpty) throw challengeRefusals.removeAt(0);

    if (!enrollmentAvailable) {
      throw const ApiException(
        'Tidak tersedia.',
        status: 404,
        code: 'DEVICE_ENROLLMENT_DISABLED',
      );
    }

    if (purpose == 'proof' && owner.enrolledFingerprint == null) {
      throw const ApiException(
        'Perangkat belum terdaftar.',
        status: 409,
        code: 'DEVICE_NOT_ENROLLED',
      );
    }

    if (purpose == 'enroll') enrolChallengeKeys.add(publicKey!);

    final fingerprint = purpose == 'enroll'
        ? DeviceKeyService.fingerprintOf(base64Decode(publicKey!))
        : owner.enrolledFingerprint!;
    final challenge = 'ch-${++_sequence}';
    _challenges[challenge] = fingerprint;

    return {
      'data': {
        'challenge': challenge,
        'purpose': purpose,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 2))
            .toIso8601String(),
        'signing_input':
            'esas-device-proof/v1|$purpose|$challenge|$workspace|'
            '${owner.id}|$token|$fingerprint',
      },
    };
  }

  Future<Map<String, dynamic>> enroll(
    String code,
    String publicKey,
    String challenge,
    String signature,
  ) async {
    final token = await _caller();
    final owner = _accountOf(token);

    if (dropNextEnrollBeforeApplying) {
      dropNextEnrollBeforeApplying = false;
      throw _timeout;
    }

    if (codes[code] != owner.id || usedCodes.contains(code)) {
      throw const ApiException(
        'Kode tidak berlaku.',
        status: 422,
        code: 'ENROLLMENT_CODE_INVALID',
      );
    }

    final fingerprint = DeviceKeyService.fingerprintOf(base64Decode(publicKey));

    if (signature != 'SIG:$fingerprint' ||
        _challenges[challenge] != fingerprint) {
      throw const ApiException(
        'Bukti tidak sah.',
        status: 403,
        code: 'DEVICE_PROOF_INVALID',
      );
    }

    enrolPublicKeys.add(publicKey);
    owner.enrolledFingerprint = fingerprint;
    usedCodes.add(code);
    enrollments++;
    _tokens.remove(token);
    final fresh = _issue(owner.id, proven: true);

    if (loseNextEnrollAnswerAfterApplying) {
      loseNextEnrollAnswerAfterApplying = false;
      throw _timeout;
    }

    return _loginShape(fresh, abilities: const ['profile', 'attendance']);
  }

  Future<Map<String, dynamic>> prove(String challenge, String signature) async {
    final token = await _caller();
    final owner = _accountOf(token);

    if (owner.enrolledFingerprint == null) {
      throw const ApiException(
        'Perangkat belum terdaftar.',
        status: 409,
        code: 'DEVICE_NOT_ENROLLED',
      );
    }

    if (signature != 'SIG:${owner.enrolledFingerprint}') {
      throw const ApiException(
        'Bukti tidak sah.',
        status: 403,
        code: 'DEVICE_PROOF_INVALID',
      );
    }

    proofs++;
    _tokens.remove(token);
    return _loginShape(
      _issue(owner.id, proven: true),
      abilities: const ['profile', 'attendance'],
    );
  }

  Future<Map<String, dynamic>> status() async {
    final token = await _caller();
    return {'data': device(token)};
  }
}

class _FakeAuthApi extends Mock implements AuthApiService {
  _FakeAuthApi(this._serverOf);

  final FakeEsasServer Function() _serverOf;

  FakeEsasServer get server => _serverOf();

  @override
  Future<Map<String, dynamic>> logout({String? fcmToken}) => server.logout();

  @override
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    required String deviceId,
    String? legacyDeviceId,
  }) => server.login(identifier, password);

  @override
  Future<Map<String, dynamic>> forgotPassword({required String identifier}) =>
      server.forgotPassword(identifier);
}

class _FakeDeviceApi extends Mock implements DeviceAuthApiService {
  _FakeDeviceApi(this._serverOf);

  final FakeEsasServer Function() _serverOf;

  FakeEsasServer get server => _serverOf();

  @override
  Future<Map<String, dynamic>> challenge({
    required String purpose,
    String? publicKey,
  }) => server.challenge(purpose, publicKey);

  @override
  Future<Map<String, dynamic>> enroll({
    required String enrollmentCode,
    required String publicKey,
    required String challenge,
    required String signature,
    required String platform,
    bool? hardwareBacked,
  }) => server.enroll(enrollmentCode, publicKey, challenge, signature);

  @override
  Future<Map<String, dynamic>> prove({
    required String challenge,
    required String signature,
  }) => server.prove(challenge, signature);

  @override
  Future<Map<String, dynamic>> status() => server.status();
}

/// The keystore behind `esas/device_key`, per alias, as the native side
/// behaves.
class FakeKeystore {
  bool available = true;
  final Map<String, Uint8List> keys = {};
  final List<({String alias, bool replace})> generateCalls = [];
  int _sequence = 0;

  Uint8List _newKey() {
    _sequence++;
    return Uint8List.fromList(
      List<int>.generate(91, (i) => (i * 31 + _sequence * 17) & 0xff),
    );
  }

  /// Put a key on the phone, as an earlier enrolment would have.
  String seed(String alias) {
    keys[alias] = _newKey();
    return fingerprint(alias);
  }

  String fingerprint(String alias) =>
      DeviceKeyService.fingerprintOf(keys[alias]!);

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(DeviceKeyService.channelName),
          _handle,
        );
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(DeviceKeyService.channelName),
          null,
        );
  }

  Map<String, Object> get _capabilities => {
    'available': available,
    'hardwareBackedClaimed': available,
    'strongBox': false,
    'platform': 'android',
  };

  Future<Object?> _handle(MethodCall call) async {
    final arguments = (call.arguments as Map?) ?? const {};
    final alias = arguments['alias'] as String?;

    Never missing() =>
        throw PlatformException(code: 'KEY_MISSING', message: 'no key');

    switch (call.method) {
      case 'capabilities':
        return _capabilities;
      case 'generate':
        if (!available) throw PlatformException(code: 'KEY_UNAVAILABLE');
        final replace = arguments['replace'] == true;
        generateCalls.add((alias: alias!, replace: replace));
        if (!keys.containsKey(alias) || replace) keys[alias] = _newKey();
        return _capabilities;
      case 'publicKey':
        return base64Encode(keys[alias] ?? missing());
      case 'sign':
        if (keys[alias] == null) missing();
        return 'SIG:${fingerprint(alias!)}';
      case 'exists':
        return keys.containsKey(alias);
      case 'delete':
        keys.remove(alias);
        return null;
    }

    return null;
  }
}

/// Counts what a person actually does on the way through a journey.
class JourneyRecorder {
  JourneyRecorder(this.name, this.tester);

  final String name;
  final WidgetTester tester;

  int taps = 0;
  int inputs = 0;
  final List<String> screens = [];
  final List<String> failurePoints = [];

  static final List<String> results = [];

  void screen(String label) {
    if (screens.isEmpty || screens.last != label) screens.add(label);
  }

  void failurePoint(String what) => failurePoints.add(what);

  Future<void> tap(Finder finder) async {
    expect(finder, findsWidgets, reason: 'nothing to tap in "$name"');
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    taps++;
    await settle(tester);
  }

  Future<void> type(Finder finder, String text) async {
    await tester.ensureVisible(finder.first);
    await tester.enterText(finder.first, text);
    inputs++;
    await tester.pump();
  }

  void record() {
    results.add(
      'JOURNEY | $name | taps=$taps | inputs=$inputs | '
      'screens=${screens.length} (${screens.join(' → ')}) | '
      'failure points=${failurePoints.isEmpty ? 'none' : failurePoints.join('; ')}',
    );
  }
}

/// Frames for animations, futures and route changes, bounded: the attendance
/// screen keeps a spinner alive, so a plain `pumpAndSettle` would never end.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _MockDeviceInfo extends Mock implements DeviceInfoService {}

class _MockHomeApi extends Mock implements HomeApiService {}

class _MockAttendanceRepository extends Mock implements AttendanceRepository {}

class _MockLocalStorage extends Mock implements LocalStorage {}

/// Everything a journey runs on.
class JourneyWorld {
  /// One workspace by default; [workspaces] for the journeys that switch.
  JourneyWorld({
    FakeEsasServer? server,
    Map<String, FakeEsasServer>? workspaces,
  }) : servers = workspaces ?? {journeyWorkspace: server ?? FakeEsasServer()} {
    currentWorkspace = servers.keys.first;
  }

  /// Each workspace's backend. Nothing is shared between them.
  final Map<String, FakeEsasServer> servers;

  /// The workspace the app is signed in to — what `TenantContext.tenant`
  /// answers in the app.
  late String currentWorkspace;

  FakeEsasServer get server => servers[currentWorkspace]!;

  final FakeKeystore keystore = FakeKeystore();
  late final SessionRepository session;
  late final AuthRepository auth;
  late final DeviceProofRepository deviceRepository;

  String get alias => aliasOf(journeyWorkspace, journeyUserId);

  String aliasOf(String workspace, int userId) =>
      DeviceKeyService.aliasFor(workspace: workspace, userId: userId);

  /// Sign out, as the profile screen does: `AuthRepository.logout`, then the
  /// sign-in screen. Not a counted tap — the journeys measure the device flow.
  Future<void> signOut(WidgetTester tester) async {
    await auth.logout();
    Get.offAllNamed(AuthRoutes.login);
    await settle(tester);
  }

  /// Switch workspace, as `SetupController.proceed` does: end the session on
  /// the old server, adopt the new workspace, open the sign-in screen.
  Future<void> switchWorkspace(WidgetTester tester, String workspace) async {
    await auth.logout();
    currentWorkspace = workspace;
    Get.offAllNamed(AuthRoutes.login);
    await settle(tester);
  }

  /// [builder] sits above the navigator, as `GetMaterialApp.builder` does in
  /// `app.dart` (the update gate lives there).
  Future<void> boot(WidgetTester tester, {TransitionBuilder? builder}) async {
    Get.testMode = true;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    keystore.install();
    addTearDown(keystore.uninstall);
    _stubPermissions();

    session = SessionRepository(
      tokenStorage: InMemoryTokenStorage(),
      localStorage: InMemoryLocalStorage(),
    );
    auth = AuthRepository(api: _FakeAuthApi(() => server), session: session);

    for (final each in servers.values) {
      each.bearer = () => session.token;
      each.onUnauthorized = () async {
        // `InitialBinding`'s handler, verbatim in effect.
        final ended = await auth.expireSession();
        if (ended && Get.currentRoute != AuthRoutes.splash) {
          Get.offAllNamed(AuthRoutes.login);
        }
      };
    }

    deviceRepository = DeviceProofRepository(
      api: _FakeDeviceApi(() => server),
      keys: DeviceKeyService(),
      session: session,
      workspace: () => currentWorkspace,
    );

    final deviceInfo = _MockDeviceInfo();
    when(() => deviceInfo.deviceId()).thenAnswer((_) async => 'dev-1');
    when(() => deviceInfo.legacyDeviceId()).thenAnswer((_) async => null);

    final homeApi = _MockHomeApi();
    when(
      () => homeApi.attendanceContext(),
    ).thenAnswer((_) async => {'attendance': <String, dynamic>{}});

    final attendance = _MockAttendanceRepository();
    when(() => attendance.context()).thenAnswer(
      (_) async => const AttendanceContext(
        attendanceEnabled: true,
        nextPresence: PresenceDirection.clockIn,
      ),
    );
    when(() => attendance.workspace).thenReturn(journeyWorkspace);

    final storage = _MockLocalStorage();
    when(() => storage.read<bool>(any())).thenReturn(null);

    Get.put<SessionRepository>(session);
    Get.put<AuthRepository>(auth);
    Get.put<DeviceInfoService>(deviceInfo);
    Get.put<DeviceProofRepository>(deviceRepository);
    Get.put<HomeRepository>(HomeRepository(api: homeApi, session: session));
    Get.put<AttendanceRepository>(attendance);
    Get.put<LocalStorage>(storage);
    Get.put<BottomNavController>(
      BottomNavController(
        destinations: const [
          HomeRoutes.home,
          AttendanceRoutes.attendance,
          PermitRoutes.permit,
          NotificationRoutes.notification,
          ProfileRoutes.profile,
        ],
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        builder: builder,
        initialRoute: AuthRoutes.login,
        getPages: [
          ...AuthPages.pages.where((page) => page.name == AuthRoutes.login),
          GetPage(
            name: HomeRoutes.home,
            page: () => const StandInBeranda(),
            binding: BindingsBuilder(() {}),
          ),
          ...AttendancePages.pages,
          ...DevicePages.pages,
        ],
      ),
    );
    await settle(tester);
  }

  void _stubPermissions() {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => switch (call.method) {
            'checkPermissionStatus' => 0,
            'requestPermissions' => <int, int>{6: 0},
            'shouldShowRequestPermissionRationale' => false,
            _ => null,
          },
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  }
}

/// Beranda, reduced to what these journeys read: the real attendance card,
/// fed by the real `HomeRepository`, above the real bottom bar.
class StandInBeranda extends StatefulWidget {
  const StandInBeranda({super.key});

  @override
  State<StandInBeranda> createState() => _StandInBerandaState();
}

class _StandInBerandaState extends State<StandInBeranda> {
  ApiException? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Get.find<HomeRepository>()
        .todayAttendance()
        .then(
          (_) {},
          onError: (Object error) {
            if (error is ApiException) _error = error;
          },
        )
        .whenComplete(() {
          if (mounted) setState(() => _loaded = true);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: !_loaded
              ? const SizedBox.shrink()
              : TodayWorkCard(
                  state: _error == null
                      ? HomeTodayState.notClockedIn
                      : HomeTodayState.unavailable,
                  shiftName: null,
                  scheduleIn: null,
                  scheduleOut: null,
                  timeIn: null,
                  timeOut: null,
                  lateMinutes: null,
                  nextPunch: AttendancePunch.clockIn,
                  canClock: _error == null,
                  dayContext: null,
                  error: _error,
                  date: null,
                  onClock: () => Get.offAllNamed(AttendanceRoutes.attendance),
                  onSignIn: () => Get.offAllNamed(AuthRoutes.login),
                  onHistory: () {},
                  onRetry: () {},
                ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }
}
