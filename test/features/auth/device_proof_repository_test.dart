import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/device_proof_repository.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/auth/data/services/device_auth_api_service.dart';
import 'package:esas/features/auth/data/services/device_key_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements DeviceAuthApiService {}

class _MockKeys extends Mock implements DeviceKeyService {}

/// ADR-D §7 and PO Putaran 5. Enrolment and proof replace the bearer token;
/// the key is per account; a bad connection never costs a key or a code.
void main() {
  late _MockApi api;
  late _MockKeys keys;
  late InMemoryTokenStorage tokens;
  late SessionRepository session;
  late DeviceProofRepository repository;
  late String workspace;

  const publicKey = 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE';
  const fingerprint = 'IlfYwWq-JnSBK58YUV9Gn79JLLxxXt8uVrs1RWXf0UI';
  const signingInput =
      'esas-device-proof/v1|proof|abc.def|acme|7|42|$fingerprint';
  final now = DateTime.utc(2026, 11, 13, 10);
  final alias7 = DeviceKeyService.aliasFor(workspace: 'acme', userId: 7);

  Map<String, dynamic> challengeBody({String purpose = 'proof'}) => {
    'data': {
      'challenge': 'abc.def',
      'purpose': purpose,
      'expires_at': '2026-11-13T10:02:00Z',
      'signing_input': signingInput.replaceFirst('proof', purpose),
    },
  };

  Map<String, dynamic> serverDevice({
    bool keyEnrolled = true,
    String? keyFingerprint = fingerprint,
    String? proofValidUntil = '2026-11-13T10:10:00Z',
    String? block,
  }) => {
    'id': 'dev-1',
    'is_registered_device': true,
    'can_record_attendance': block == null,
    'proof_required': true,
    'enrollment_available': true,
    'key_enrolled': keyEnrolled,
    'key_fingerprint': keyFingerprint,
    'proof_valid_until': proofValidUntil,
    'attendance_block': block,
  };

  Map<String, dynamic> loginShape(String token) => {
    'token': token,
    'user': {'id': 7, 'name': 'Budi', 'nip': '20240113'},
    'abilities': ['profile', 'attendance'],
    'device': serverDevice(),
  };

  ApiException refusal(int status, String code) =>
      ApiException('refused', status: status, code: code);

  const timeout = ApiException('timeout', code: 'timeout');
  const unauthenticated = ApiException('sesi', status: 401);

  Future<void> signIn({int userId = 7, Map<String, dynamic>? device}) =>
      session.save(
        token: 'old-token',
        user: AuthUser.fromJson({
          'id': userId,
          'name': 'Budi',
          'nip': '20240113',
          'abilities': ['profile'],
          'device':
              device ??
              serverDevice(
                proofValidUntil: null,
                block: 'DEVICE_PROOF_REQUIRED',
              ),
        }),
      );

  void enrollAnswers(Future<Map<String, dynamic>> Function() answer) => when(
    () => api.enroll(
      enrollmentCode: any(named: 'enrollmentCode'),
      publicKey: any(named: 'publicKey'),
      challenge: any(named: 'challenge'),
      signature: any(named: 'signature'),
      platform: any(named: 'platform'),
      hardwareBacked: any(named: 'hardwareBacked'),
    ),
  ).thenAnswer((_) => answer());

  void proveAnswers(Future<Map<String, dynamic>> Function() answer) => when(
    () => api.prove(
      challenge: any(named: 'challenge'),
      signature: any(named: 'signature'),
    ),
  ).thenAnswer((_) => answer());

  void statusAnswers(Future<Map<String, dynamic>> Function() answer) =>
      when(() => api.status()).thenAnswer((_) => answer());

  setUp(() async {
    api = _MockApi();
    keys = _MockKeys();
    tokens = InMemoryTokenStorage();
    workspace = 'acme';
    session = SessionRepository(
      tokenStorage: tokens,
      localStorage: InMemoryLocalStorage(),
    );
    repository = DeviceProofRepository(
      api: api,
      keys: keys,
      session: session,
      workspace: () => workspace,
      now: () => now,
    );

    when(() => keys.exists(any())).thenAnswer((_) async => true);
    when(() => keys.delete(any())).thenAnswer((_) async {});
    when(() => keys.fingerprint(any())).thenAnswer((_) async => fingerprint);
    when(() => keys.publicKey(any())).thenAnswer((_) async => publicKey);
    when(() => keys.signText(any(), any())).thenAnswer((_) async => 'MEUCIQ==');
    when(() => keys.capabilities(alias: any(named: 'alias'))).thenAnswer(
      (_) async => const DeviceKeyCapabilities(
        available: true,
        hardwareBackedClaimed: false,
        strongBox: false,
        platform: 'android',
      ),
    );
    when(
      () => keys.generate(
        alias: any(named: 'alias'),
        replace: any(named: 'replace'),
      ),
    ).thenAnswer(
      (_) async => const DeviceKeyCapabilities(
        available: true,
        hardwareBackedClaimed: true,
        strongBox: true,
        platform: 'android',
      ),
    );
    when(
      () => api.challenge(
        purpose: any(named: 'purpose'),
        publicKey: any(named: 'publicKey'),
      ),
    ).thenAnswer(
      (invocation) async =>
          challengeBody(purpose: invocation.namedArguments[#purpose] as String),
    );
    proveAnswers(() async => loginShape('new-token'));
    enrollAnswers(() async => loginShape('enrolled-token'));

    await signIn();
  });

  group('one key per account (PO 4.2.8)', () {
    test('the key is named for this user in this workspace', () async {
      await repository.prove();

      verify(() => keys.exists(alias7)).called(1);
      verify(() => keys.signText(alias7, signingInput)).called(1);
    });

    test('another account on the same phone uses its own key', () async {
      await signIn(userId: 8);

      await repository.prove();

      final alias8 = DeviceKeyService.aliasFor(workspace: 'acme', userId: 8);
      verify(() => keys.exists(alias8)).called(1);
      verifyNever(() => keys.exists(alias7));
      verifyNever(() => keys.signText(alias7, any()));
    });

    test('another workspace uses another key', () async {
      workspace = 'globex';

      await repository.prove();

      final other = DeviceKeyService.aliasFor(workspace: 'globex', userId: 7);
      verify(() => keys.exists(other)).called(1);
      verifyNever(() => keys.exists(alias7));
    });

    test('enrolling account B never replaces account A\'s key', () async {
      await signIn(
        userId: 8,
        device: serverDevice(keyEnrolled: false, keyFingerprint: null),
      );
      when(() => keys.exists(any())).thenAnswer((_) async => false);

      await repository.enroll('ABCDEFGHJK');

      final alias8 = DeviceKeyService.aliasFor(workspace: 'acme', userId: 8);
      verify(() => keys.generate(alias: alias8, replace: true)).called(1);
      verifyNever(
        () => keys.generate(
          alias: alias7,
          replace: any(named: 'replace'),
        ),
      );
    });
  });

  group('proof', () {
    test('signs the server signing input and replaces the token', () async {
      final device = await repository.prove();

      verify(() => keys.signText(alias7, signingInput)).called(1);
      verify(
        () => api.prove(challenge: 'abc.def', signature: 'MEUCIQ=='),
      ).called(1);
      expect(session.token, 'new-token');
      expect(tokens.token, 'new-token');
      expect(device?.proofValidUntil, DateTime.utc(2026, 11, 13, 10, 10));
      expect(session.user?.canRecordAttendance, isTrue);
      expect(repository.current?.attendanceBlock, isNull);
    });

    test('after a re-login (or an iOS reinstall that kept the key), the '
        'surviving key proves with no HR code', () async {
      // A fresh sign-in: a new token, the server's key is this phone's.
      await session.save(
        token: 'fresh-login-token',
        user: AuthUser.fromJson({
          'id': 7,
          'device': serverDevice(
            proofValidUntil: null,
            block: 'DEVICE_PROOF_REQUIRED',
          ),
        }),
      );

      await repository.prove();

      verifyNever(
        () => keys.generate(
          alias: any(named: 'alias'),
          replace: any(named: 'replace'),
        ),
      );
      verifyNever(
        () => api.enroll(
          enrollmentCode: any(named: 'enrollmentCode'),
          publicKey: any(named: 'publicKey'),
          challenge: any(named: 'challenge'),
          signature: any(named: 'signature'),
          platform: any(named: 'platform'),
          hardwareBacked: any(named: 'hardwareBacked'),
        ),
      );
      expect(session.token, 'new-token');
    });

    test('keeps the token even when the reply leaves out the user', () async {
      proveAnswers(
        () async => {'token': 'new-token', 'device': serverDevice()},
      );

      await repository.prove();

      expect(session.token, 'new-token');
      expect(session.user?.name, 'Budi');
      expect(session.user?.raw['abilities'], ['profile']);
      expect(repository.current?.keyEnrolled, isTrue);
    });

    test('asks for a new challenge once when one expired', () async {
      var attempts = 0;
      proveAnswers(() async {
        if (attempts++ == 0) throw refusal(422, 'CHALLENGE_EXPIRED');
        return loginShape('new-token');
      });

      await repository.prove();

      verify(() => api.challenge(purpose: 'proof')).called(2);
      expect(session.token, 'new-token');
    });

    test('a second stale challenge is not retried again', () async {
      proveAnswers(() async => throw refusal(409, 'CHALLENGE_REUSED'));

      await expectLater(
        repository.prove(),
        throwsA(_failure(DeviceProofFailure.challengeExpired)),
      );
      verify(() => api.challenge(purpose: 'proof')).called(2);
      expect(session.token, 'old-token');
    });

    test('no key on this install is a recovery, without a request', () async {
      when(() => keys.exists(any())).thenAnswer((_) async => false);

      await expectLater(
        repository.prove(),
        throwsA(_failure(DeviceProofFailure.keyMissing)),
      );
      verifyNever(() => api.challenge(purpose: any(named: 'purpose')));
    });

    test('a key that is not the enrolled one is not sent, and never '
        'replaced', () async {
      when(() => keys.fingerprint(any())).thenAnswer((_) async => 'other');

      await expectLater(
        repository.prove(),
        throwsA(_failure(DeviceProofFailure.proofInvalid)),
      );
      verifyNever(() => api.challenge(purpose: any(named: 'purpose')));
      verifyNever(
        () => keys.generate(
          alias: any(named: 'alias'),
          replace: any(named: 'replace'),
        ),
      );
    });

    for (final (status, code, failure) in [
      (409, 'DEVICE_NOT_ENROLLED', DeviceProofFailure.notEnrolled),
      (403, 'DEVICE_PROOF_INVALID', DeviceProofFailure.proofInvalid),
      (422, 'DEVICE_KEY_UNSUPPORTED', DeviceProofFailure.keyUnsupported),
      (404, 'DEVICE_ENROLLMENT_DISABLED', DeviceProofFailure.disabled),
      (429, 'too_many', DeviceProofFailure.rateLimited),
      (500, 'server_error', DeviceProofFailure.failed),
    ]) {
      test('$status $code is ${failure.name}', () async {
        when(
          () => api.challenge(purpose: 'proof'),
        ).thenThrow(refusal(status, code));

        await expectLater(repository.prove(), throwsA(_failure(failure)));
        expect(session.token, 'old-token');
      });
    }

    test('401 is the session ending, not "no connection"', () async {
      when(() => api.challenge(purpose: 'proof')).thenThrow(unauthenticated);

      await expectLater(
        repository.prove(),
        throwsA(_failure(DeviceProofFailure.sessionEnded)),
      );
    });

    test('a broken keystore while signing is key-unavailable', () async {
      when(() => keys.signText(any(), any())).thenThrow(
        const DeviceKeyException(
          DeviceKeyFailure.unavailable,
          code: 'KEY_UNAVAILABLE',
        ),
      );

      await expectLater(
        repository.prove(),
        throwsA(_failure(DeviceProofFailure.keyUnavailable)),
      );
    });
  });

  group('proof over a bad connection', () {
    setUp(() => proveAnswers(() async => throw timeout));

    test('no answer, and the status says the token was replaced (401): '
        'sign in again', () async {
      statusAnswers(() async => throw unauthenticated);

      await expectLater(
        repository.prove(),
        throwsA(_failure(DeviceProofFailure.sessionEnded)),
      );
    });

    test('no answer, and the status cannot be read either: offline', () async {
      statusAnswers(() async => throw timeout);

      await expectLater(
        repository.prove(),
        throwsA(_failure(DeviceProofFailure.offline)),
      );
    });

    test('no answer, but this token is already proven: success', () async {
      statusAnswers(() async => {'data': serverDevice()});

      final device = await repository.prove();

      expect(device?.keyEnrolled, isTrue);
      expect(session.token, 'old-token');
    });

    test('no answer, key enrolled but this token not proven: retry', () async {
      statusAnswers(
        () async => {
          'data': serverDevice(
            proofValidUntil: null,
            block: 'DEVICE_PROOF_REQUIRED',
          ),
        },
      );

      await expectLater(
        repository.prove(),
        throwsA(_failure(DeviceProofFailure.offline)),
      );
    });

    test('no answer, and HR has released the key meanwhile', () async {
      statusAnswers(
        () async => {
          'data': serverDevice(keyEnrolled: false, keyFingerprint: null),
        },
      );

      await expectLater(
        repository.prove(),
        throwsA(_failure(DeviceProofFailure.notEnrolled)),
      );
    });
  });

  group('enrolment', () {
    setUp(() async {
      await signIn(
        device: serverDevice(
          keyEnrolled: false,
          keyFingerprint: null,
          proofValidUntil: null,
          block: 'DEVICE_NOT_ENROLLED',
        ),
      );
      when(() => keys.exists(any())).thenAnswer((_) async => false);
    });

    test('runs key → challenge → signature → enrolment, and swaps the '
        'token', () async {
      final device = await repository.enroll('abcde-fghjk');

      verifyInOrder([
        () => keys.capabilities(alias: alias7),
        () => keys.generate(alias: alias7, replace: true),
        () => keys.publicKey(alias7),
        () => api.challenge(purpose: 'enroll', publicKey: publicKey),
        () =>
            keys.signText(alias7, signingInput.replaceFirst('proof', 'enroll')),
        () => api.enroll(
          enrollmentCode: 'ABCDEFGHJK',
          publicKey: publicKey,
          challenge: 'abc.def',
          signature: 'MEUCIQ==',
          platform: 'android',
          hardwareBacked: true,
        ),
      ]);
      expect(session.token, 'enrolled-token');
      expect(device?.keyEnrolled, isTrue);
      expect(session.user?.raw['abilities'], contains('attendance'));
    });

    test(
      'removes the Putaran 4 fixed-name key once, and nothing else',
      () async {
        await repository.enroll('ABCDEFGHJK');
        await repository.enroll('ABCDEFGHJK', freshKey: false);

        verify(() => keys.delete(DeviceKeyService.legacyAlias)).called(1);
        verifyNever(() => keys.delete(alias7));
        expect(alias7, isNot(DeviceKeyService.legacyAlias));
      },
    );

    test(
      'a keystore that will not remove the old key changes nothing',
      () async {
        when(() => keys.delete(DeviceKeyService.legacyAlias)).thenThrow(
          const DeviceKeyException(
            DeviceKeyFailure.unavailable,
            code: 'KEY_UNAVAILABLE',
          ),
        );

        await repository.enroll('ABCDEFGHJK');

        expect(session.token, 'enrolled-token');
      },
    );

    test('a retry reuses the key already on the phone', () async {
      when(() => keys.exists(any())).thenAnswer((_) async => true);

      await repository.enroll('ABCDEFGHJK', freshKey: false);

      verify(() => keys.generate(alias: alias7, replace: false)).called(1);
      verifyNever(() => keys.generate(alias: alias7, replace: true));
      verifyNever(() => api.status());
    });

    test('a rebind replaces a key the server does not hold', () async {
      when(() => keys.exists(any())).thenAnswer((_) async => true);
      statusAnswers(
        () async => {
          'data': serverDevice(keyEnrolled: false, keyFingerprint: null),
        },
      );

      await repository.enroll('ABCDEFGHJK');

      verify(() => keys.generate(alias: alias7, replace: true)).called(1);
      expect(session.token, 'enrolled-token');
    });

    test('a key the server already holds is never replaced: the earlier '
        'enrolment is reported as done, and the code is not spent', () async {
      when(() => keys.exists(any())).thenAnswer((_) async => true);
      statusAnswers(() async => {'data': serverDevice()});

      final device = await repository.enroll('ABCDEFGHJK');

      expect(device?.keyEnrolled, isTrue);
      verifyNever(
        () => keys.generate(
          alias: any(named: 'alias'),
          replace: any(named: 'replace'),
        ),
      );
      verifyNever(
        () => api.enroll(
          enrollmentCode: any(named: 'enrollmentCode'),
          publicKey: any(named: 'publicKey'),
          challenge: any(named: 'challenge'),
          signature: any(named: 'signature'),
          platform: any(named: 'platform'),
          hardwareBacked: any(named: 'hardwareBacked'),
        ),
      );
    });

    test('an incomplete code is refused before anything is made', () async {
      await expectLater(
        repository.enroll('ABCD'),
        throwsA(_failure(DeviceProofFailure.invalidCode)),
      );
      verifyNever(
        () => keys.generate(
          alias: any(named: 'alias'),
          replace: any(named: 'replace'),
        ),
      );
    });

    test('ENROLLMENT_CODE_INVALID is one answer for every bad code', () async {
      enrollAnswers(() async => throw refusal(422, 'ENROLLMENT_CODE_INVALID'));

      await expectLater(
        repository.enroll('ABCDEFGHJK'),
        throwsA(_failure(DeviceProofFailure.invalidCode)),
      );
      expect(session.token, 'old-token');
    });

    test('a phone without a usable keystore says so', () async {
      when(() => keys.capabilities(alias: any(named: 'alias'))).thenAnswer(
        (_) async => const DeviceKeyCapabilities(
          available: false,
          hardwareBackedClaimed: false,
          strongBox: false,
          platform: 'android',
        ),
      );

      await expectLater(
        repository.enroll('ABCDEFGHJK'),
        throwsA(_failure(DeviceProofFailure.keyUnavailable)),
      );
    });
  });

  group('enrolment over a bad connection', () {
    setUp(() async {
      await signIn(
        device: serverDevice(
          keyEnrolled: false,
          keyFingerprint: null,
          proofValidUntil: null,
          block: 'DEVICE_NOT_ENROLLED',
        ),
      );
      enrollAnswers(() async => throw timeout);
    });

    test('no answer, but the server holds this phone\'s key: success, '
        'nothing redone', () async {
      statusAnswers(() async => {'data': serverDevice()});

      final device = await repository.enroll('ABCDEFGHJK', freshKey: false);

      expect(device?.keyEnrolled, isTrue);
      verify(
        () => api.enroll(
          enrollmentCode: any(named: 'enrollmentCode'),
          publicKey: any(named: 'publicKey'),
          challenge: any(named: 'challenge'),
          signature: any(named: 'signature'),
          platform: any(named: 'platform'),
          hardwareBacked: any(named: 'hardwareBacked'),
        ),
      ).called(1);
    });

    test('no answer, and the token was replaced (401): sign in again; the '
        'key stays on the phone', () async {
      statusAnswers(() async => throw unauthenticated);

      await expectLater(
        repository.enroll('ABCDEFGHJK', freshKey: false),
        throwsA(_failure(DeviceProofFailure.sessionEnded)),
      );
      verifyNever(() => keys.delete(alias7));
    });

    test(
      'no answer and no status: offline, and the retry reuses the key',
      () async {
        statusAnswers(() async => throw timeout);

        await expectLater(
          repository.enroll('ABCDEFGHJK', freshKey: false),
          throwsA(_failure(DeviceProofFailure.offline)),
        );

        enrollAnswers(() async => loginShape('enrolled-token'));
        await repository.enroll('ABCDEFGHJK', freshKey: false);

        verify(() => keys.generate(alias: alias7, replace: false)).called(2);
        verifyNever(() => keys.generate(alias: alias7, replace: true));
        expect(session.token, 'enrolled-token');
      },
    );

    test('no answer, and the server does not hold the key: offline', () async {
      statusAnswers(
        () async => {
          'data': serverDevice(keyEnrolled: false, keyFingerprint: null),
        },
      );

      await expectLater(
        repository.enroll('ABCDEFGHJK', freshKey: false),
        throwsA(_failure(DeviceProofFailure.offline)),
      );
    });
  });

  group('busy shift and a rate limiter that is down (Putaran 9)', () {
    test(
      '429 is "busy", carries the server\'s wait, and signs nobody out',
      () async {
        when(() => api.challenge(purpose: 'proof')).thenThrow(
          const ApiException(
            'Too Many Attempts.',
            status: 429,
            code: 'TOO_MANY_REQUESTS',
            retryAfter: Duration(seconds: 20),
          ),
        );

        await expectLater(
          repository.prove(),
          throwsA(
            _failure(DeviceProofFailure.rateLimited).having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 20),
            ),
          ),
        );
        expect(session.token, 'old-token');
      },
    );

    test(
      '503 RATE_LIMITER_UNAVAILABLE is its own answer, with its wait',
      () async {
        when(() => api.challenge(purpose: 'proof')).thenThrow(
          const ApiException(
            'Pemeriksaan perangkat sedang tidak tersedia.',
            status: 503,
            code: 'RATE_LIMITER_UNAVAILABLE',
            retryAfter: Duration(seconds: 30),
          ),
        );

        await expectLater(
          repository.prove(),
          throwsA(
            _failure(DeviceProofFailure.limiterUnavailable).having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 30),
            ),
          ),
        );
        expect(session.token, 'old-token');
      },
    );

    test('a busy answer without Retry-After still waits a little', () async {
      when(
        () => api.challenge(purpose: 'proof'),
      ).thenThrow(const ApiException('Too Many Attempts.', status: 429));

      await expectLater(
        repository.prove(),
        throwsA(
          _failure(DeviceProofFailure.rateLimited).having(
            (e) => e.retryAfter,
            'retryAfter',
            DeviceProofRepository.defaultBusyWait,
          ),
        ),
      );
    });

    test('a 500 is not "busy" and asks for no wait', () async {
      when(
        () => api.challenge(purpose: 'proof'),
      ).thenThrow(const ApiException('Server Error', status: 500));

      await expectLater(
        repository.prove(),
        throwsA(
          _failure(
            DeviceProofFailure.failed,
          ).having((e) => e.retryAfter, 'retryAfter', isNull),
        ),
      );
    });
  });

  group('per-workspace identity (Putaran 8, cross-workspace)', () {
    test('the same numeric user in two workspaces is two people', () async {
      final inAcme = repository.userKey;
      workspace = 'globex';
      final inGlobex = repository.userKey;

      expect(inAcme, isNotNull);
      expect(inGlobex, isNot(inAcme));
    });
  });

  group('status', () {
    test('keeps the device object and leaves the token alone', () async {
      statusAnswers(() async => {'data': serverDevice()});

      final device = await repository.refreshStatus();

      expect(device.canRecordAttendance, isTrue);
      expect(repository.current?.proofValidUntil, isNotNull);
      expect(session.token, 'old-token');
      expect(session.user?.name, 'Budi');
    });

    test('this phone\'s fingerprint, or none', () async {
      expect(await repository.localFingerprint(), fingerprint);

      when(() => keys.exists(any())).thenAnswer((_) async => false);

      expect(await repository.localFingerprint(), isNull);
    });
  });
}

TypeMatcher<DeviceProofException> _failure(DeviceProofFailure failure) =>
    isA<DeviceProofException>().having((e) => e.failure, 'failure', failure);
