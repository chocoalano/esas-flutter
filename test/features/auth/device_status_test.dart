import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/models/device_status.dart';
import 'package:esas/features/auth/data/models/enrollment_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the device object (ADR-D §7)', () {
    test('reads every field', () {
      final device = DeviceStatus.fromJson({
        'id': 'a1b2c3',
        'is_registered_device': true,
        'can_record_attendance': false,
        'proof_required': true,
        'enrollment_available': true,
        'key_enrolled': true,
        'key_fingerprint': 'IlfYwWq-JnSBK58YUV9Gn79JLLxxXt8uVrs1RWXf0UI',
        'proof_valid_until': '2026-11-13T10:10:00+07:00',
        'attendance_block': 'DEVICE_PROOF_REQUIRED',
      });

      expect(device.id, 'a1b2c3');
      expect(device.isRegisteredDevice, isTrue);
      expect(device.canRecordAttendance, isFalse);
      expect(device.proofRequired, isTrue);
      expect(device.enrollmentAvailable, isTrue);
      expect(device.keyEnrolled, isTrue);
      expect(device.keyFingerprint, startsWith('IlfY'));
      expect(device.proofValidUntil, DateTime.utc(2026, 11, 13, 3, 10));
      expect(device.attendanceBlock, AttendanceBlock.deviceProofRequired);
    });

    test('a pre-ADR-D object changes nothing', () {
      final device = DeviceStatus.fromJson({
        'id': 'a1b2c3',
        'is_registered_device': true,
        'can_record_attendance': true,
      });

      expect(device.proofRequired, isFalse);
      expect(device.enrollmentAvailable, isFalse);
      expect(device.keyEnrolled, isFalse);
      expect(device.proofValidUntil, isNull);
      expect(device.attendanceBlock, isNull);
    });

    test('reads each block, and an unknown one as unknown', () {
      expect(AttendanceBlock.parse(null), isNull);
      expect(
        AttendanceBlock.parse('DEVICE_NOT_REGISTERED'),
        AttendanceBlock.deviceNotRegistered,
      );
      expect(
        AttendanceBlock.parse('DEVICE_NOT_ENROLLED'),
        AttendanceBlock.deviceNotEnrolled,
      );
      expect(
        AttendanceBlock.parse('DEVICE_PROOF_REQUIRED'),
        AttendanceBlock.deviceProofRequired,
      );
      expect(AttendanceBlock.parse('SOMETHING_NEW'), AttendanceBlock.unknown);
    });

    test('is read from the session user', () {
      final user = AuthUser.fromJson({
        'id': 7,
        'device': {'proof_required': true, 'key_enrolled': false},
      });

      expect(DeviceStatus.fromUser(user)?.proofRequired, isTrue);
      expect(DeviceStatus.fromUser(AuthUser.fromJson({'id': 7})), isNull);
      expect(DeviceStatus.fromUser(null), isNull);
    });

    test('shows the short ID the HR panel shows, never the fingerprint', () {
      const device = DeviceStatus(
        keyFingerprint: 'IlfYwWq-JnSBK58YUV9Gn79JLLxxXt8uVrs1RWXf0UI',
      );

      // The panel reads "kunci …WXf0UI" (DeviceStatusSummary: '…' + the last
      // six characters). Before Putaran 8 the app showed "2257-D8C1", which
      // nobody could match on a phone call to HR.
      expect(device.shortId, '…WXf0UI');
      expect(const DeviceStatus().shortId, isNull);
      expect(const DeviceStatus(keyFingerprint: 'abc').shortId, '…abc');
    });
  });

  group('the challenge', () {
    test('is read from data', () {
      final challenge = DeviceChallenge.fromBody({
        'data': {
          'challenge': 'abc.def',
          'purpose': 'proof',
          'expires_at': '2026-11-13T10:02:00Z',
          'signing_input': 'esas-device-proof/v1|proof|abc.def|t|7|42|fp',
        },
      });

      expect(challenge.challenge, 'abc.def');
      expect(challenge.purpose, 'proof');
      expect(challenge.expiresAt, DateTime.utc(2026, 11, 13, 10, 2));
      expect(
        challenge.signingInput,
        'esas-device-proof/v1|proof|abc.def|t|7|42|fp',
      );
    });

    test('keeps the signing input byte for byte', () {
      final challenge = DeviceChallenge.fromBody({
        'data': {'challenge': 'c', 'signing_input': ' a|b '},
      });

      expect(challenge.signingInput, ' a|b ');
    });

    test('without a signing input is malformed', () {
      expect(
        () => DeviceChallenge.fromBody({
          'data': {'challenge': 'c'},
        }),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('the activation code (ADR-D §4)', () {
    test('normalises the way the server does', () {
      expect(EnrollmentCode.normalize('abcde-fghjk'), 'ABCDEFGHJK');
      expect(EnrollmentCode.normalize('O0IL1 23'), '0011123');
    });

    test('is ten Crockford symbols', () {
      expect(EnrollmentCode.isValid('ABCDE12345'), isTrue);
      expect(EnrollmentCode.isValid('ABCDE1234'), isFalse);
      expect(EnrollmentCode.isValid('ABCDE1234U'), isFalse, reason: 'no U');
      expect(EnrollmentCode.isValid('ABCDE12345X'), isFalse);
    });

    test('is shown as XXXXX-XXXXX', () {
      expect(EnrollmentCode.format('ABC'), 'ABC');
      expect(EnrollmentCode.format('ABCDE'), 'ABCDE');
      expect(EnrollmentCode.format('ABCDE1'), 'ABCDE-1');
      expect(EnrollmentCode.format('ABCDE12345'), 'ABCDE-12345');
    });

    test('a pasted code keeps its dashes and spaces out of the way', () {
      expect(EnrollmentCode.sanitize(' abcde-12345 '), 'ABCDE12345');
      expect(EnrollmentCode.sanitize('abcde 12345'), 'ABCDE12345');
    });

    test('a code pasted inside a sentence is picked out whole', () {
      // Before: the letters of "Kode" became the first symbols —
      // "K0DEABCDE1", a wrong code that cost one of five attempts.
      expect(EnrollmentCode.sanitize('Kode: ABCDE-12345'), 'ABCDE12345');
      expect(
        EnrollmentCode.sanitize(
          'Kode aktivasi Anda: abcde-12345. Berlaku 15 menit.',
        ),
        'ABCDE12345',
      );
      expect(
        EnrollmentCode.sanitize('kode: o0il1-23456'),
        '00111'
        '23456',
      );
    });

    test('typing is unchanged by the paste rule', () {
      expect(EnrollmentCode.sanitize('ABCDE-1'), 'ABCDE1');
      expect(EnrollmentCode.sanitize('ABCDE-12345'), 'ABCDE12345');
      expect(EnrollmentCode.sanitize('ABCDE-12345X'), 'ABCDE12345');
    });

    test('the field drops what cannot be in a code and caps the length', () {
      const formatter = EnrollmentCodeInputFormatter();

      TextEditingValue type(String text) => formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: text),
      );

      expect(type('abcdeu!fghjk99').text, 'ABCDE-FGHJK');
      expect(type('ol1ol').text, '01101');
      expect(type('abcde-').text, 'ABCDE');
      expect(type('abcdef').selection.baseOffset, 'ABCDE-F'.length);
    });
  });
}
