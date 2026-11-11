import 'package:esas/core/network/api_exception.dart';
import 'dart:io';
import 'dart:async';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/storage_keys.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/profile/data/repositories/profile_repository.dart';
import 'package:esas/features/profile/data/services/profile_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _ProfileApi extends Mock implements ProfileApiService {}

/// PROF-01. The cached session is written to GetStorage — a plaintext JSON
/// file in the documents directory, included in device backups. It used to
/// receive the whole `/profile` reply: salary, bank account, NIK, family.
void main() {
  const sensitiveTopLevel = [
    'salary',
    'detail',
    'addresses',
    'families',
    'educations',
    'informal_educations',
    'experiences',
  ];
  const sensitiveEmployee = ['bank_name', 'bank_number', 'bank_holder'];

  Map<String, dynamic> profileBody() => {
    'user': {
      'id': 7,
      'name': 'Budi',
      'nip': '20240113',
      'email': 'budi@example.com',
      'avatar': 'avatars/budi.png',
      'status': 'active',
    },
    'company': {
      'id': 1,
      'name': 'Acme',
      'latitude': -6.17,
      'longitude': 106.59,
      'radius': 100,
    },
    'employee': {
      'user_id': 7,
      'departement_id': 3,
      'departement': 'IT',
      'job_position': 'Engineer',
      'job_level': 'Staff',
      'join_date': '2020-01-06',
      'sign_date': '2020-01-06',
      'bank_name': 'BCA',
      'bank_number': '1234567890',
      'bank_holder': 'Budi',
    },
    'detail': {'birth_date': '1990-01-01', 'blood_type': 'O'},
    'addresses': [
      {'identity_numbers': '3201010101900001'},
    ],
    'salary': {'basic_salary': '5000000.00'},
    'families': [
      {'name': 'Ani'},
    ],
    'educations': const [],
    'informal_educations': const [],
    'experiences': const [],
  };

  Map<String, dynamic> loginUser() => {
    'id': 7,
    'tenant_id': 'acme',
    'name': 'Budi',
    'nip': '20240113',
    'job_position': 'Engineer',
    'active_modules': ['hrms'],
    'is_approver': false,
    'timezone': {'id': 'Asia/Jakarta', 'abbreviation': 'WIB', 'offset': 7},
    'abilities': ['attendance'],
    'device': {'can_record_attendance': true},
  };

  void expectNothingSensitive(Map<dynamic, dynamic>? stored) {
    expect(stored, isNotNull);
    for (final key in sensitiveTopLevel) {
      expect(stored!.containsKey(key), isFalse, reason: key);
    }
    final employee = stored!['employee'];
    if (employee is Map) {
      for (final key in sensitiveEmployee) {
        expect(employee.containsKey(key), isFalse, reason: 'employee.$key');
      }
    }
  }

  group('what the session writes to the device', () {
    late InMemoryLocalStorage local;
    late SessionRepository session;

    setUp(() {
      local = InMemoryLocalStorage();
      session = SessionRepository(
        tokenStorage: InMemoryTokenStorage(),
        localStorage: local,
      );
    });

    Map<dynamic, dynamic>? stored() =>
        local.read<Map<dynamic, dynamic>>(StorageKeys.legacy.userJson);

    test('never includes payroll, bank or identity numbers', () async {
      await session.save(
        token: 'abc',
        user: AuthUser.fromJson({...loginUser(), ...profileBody()}),
      );

      expectNothingSensitive(stored());
    });

    test('still includes what the app reads from the session', () async {
      await session.save(
        token: 'abc',
        user: AuthUser.fromJson({...loginUser(), ...profileBody()}),
      );

      final kept = stored()!;
      expect(kept['name'], 'Budi');
      expect(kept['tenant_id'], 'acme');
      expect(kept['timezone'], isA<Map<dynamic, dynamic>>());
      expect(kept['abilities'], ['attendance']);
      expect(kept['device'], {'can_record_attendance': true});
      expect(kept['active_modules'], ['hrms']);
      expect((kept['employee'] as Map)['departement_id'], 3);
      expect((kept['employee'] as Map)['sign_date'], '2020-01-06');
    });

    test('scrubs a record an older version already wrote', () async {
      await local.write(StorageKeys.legacy.userJson, {
        ...loginUser(),
        ...profileBody(),
      });

      await session.restore();

      expectNothingSensitive(stored());
      expect(session.user?.raw.containsKey('salary'), isFalse);
      expect(session.user?.name, 'Budi');
    });
  });

  group('opening the profile', () {
    test('does not copy the sensitive record into the session', () async {
      final local = InMemoryLocalStorage();
      final session = SessionRepository(
        tokenStorage: InMemoryTokenStorage(),
        localStorage: local,
      );
      await session.save(token: 'abc', user: AuthUser.fromJson(loginUser()));

      final api = _ProfileApi();
      when(() => api.profile()).thenAnswer((_) async => profileBody());

      final user = await ProfileRepository(
        api: api,
        session: session,
      ).currentUser();

      // The screens still get everything — from memory.
      expect(user.salaries, isNotNull);
      expect(user.employee?.bankNumber, '1234567890');

      // The session does not.
      expectNothingSensitive(session.user?.raw);
      expectNothingSensitive(
        local.read<Map<dynamic, dynamic>>(StorageKeys.legacy.userJson),
      );
      expect(session.user?.raw['tenant_id'], 'acme');
    });
  });

  // PROF-04. The upload's answer was written to whichever session was signed in
  // when it arrived. Employee A signs out mid-upload, B signs in — and B's
  // session got A's photograph.
  test('an avatar answered after a change of session is not applied', () async {
    registerFallbackValue(File(''));

    final local = InMemoryLocalStorage();
    final tokens = InMemoryTokenStorage();
    final session = SessionRepository(tokenStorage: tokens, localStorage: local);
    await session.save(token: 'token-a', user: AuthUser.fromJson({'id': 1}));

    final api = _ProfileApi();
    final upload = Completer<Map<String, dynamic>>();
    when(() => api.uploadAvatar(any())).thenAnswer((_) => upload.future);

    final pending = ProfileRepository(
      api: api,
      session: session,
    ).uploadAvatar(File('${Directory.systemTemp.path}/a.jpg'));

    await session.clear();
    await session.save(token: 'token-b', user: AuthUser.fromJson({'id': 2}));
    upload.complete({'avatar': 'avatars/a.jpg'});

    await expectLater(pending, throwsA(isA<ApiException>()));
    expect(session.user?.avatar, isNull);
  });
}
