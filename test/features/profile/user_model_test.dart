import 'package:esas/features/profile/data/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

/// The payload the profile screen is built from, and the crash it used to be.
///
/// `User.fromJson` was generated against the retired backend and read every
/// field with an unguarded cast. The one that actually fired in production said:
///
/// ```
/// type 'String' is not a subtype of type 'Map<String, dynamic>'
/// ```
///
/// `/auth/me` flattens `company` to its **name** — it answers *who you are*, not
/// *what your employee record is* — and `Company.fromJson("PT Sinergi")` throws
/// before the screen draws anything. The repository reads `/profile` now, and
/// this pins both halves: the shape it does read, and the shapes that must no
/// longer be able to take the screen down.
void main() {
  group('the /profile shape, as the repository reshapes it', () {
    test('reads the whole employee record', () {
      final user = User.fromJson({
        'id': 1,
        'name': 'Budi',
        'nip': 'EMP0001',
        'company_id': 3,
        'company': {
          'id': 3,
          'name': 'PT Sinergi',
          // Decimal *strings*, which is what the HRIS stores and what
          // `json["latitude"]?.toDouble()` used to choke on.
          'latitude': '-6.175',
          'longitude': '106.827',
          'radius': 150,
        },
        'employee': {
          'user_id': 1,
          'departement_id': 3,
          'departement': {'id': 3, 'name': 'Produksi'},
          'job_position': {'id': null, 'name': 'Operator'},
          'sign_date': '2021-03-01',
        },
        'details': {'phone': '08120000000', 'datebirth': '1995-01-20'},
        'address': {'city': 'Bandung'},
        'salaries': {'basic_salary': 5000000, 'payment_type': 'Monthly'},
        'families': [
          {'fullname': 'Siti', 'relationship': 'wife'},
        ],
        'formal_educations': [
          {
            'id': 9,
            'user_id': 1,
            'institution': 'SMKN 1',
            'majors': 'Mesin',
            // A string, because `score` is a string column. This was
            // `(json['score'] as num).toDouble()`.
            'score': '8.1',
            // Integer years, because that is what the columns hold. This was
            // `DateTime.tryParse(json['start'])`, and tryParse takes a String.
            'start': 2010,
            'finish': 2013,
            'status': 'passed',
            'certification': true,
          },
        ],
        'work_experiences': [
          {
            'id': 4,
            'user_id': 1,
            'company_name': 'PT Lama',
            'position': 'Teknisi',
            'start': 2014,
            'finish': 2020,
            'certification': false,
          },
        ],
      });

      expect(user.name, 'Budi');
      expect(user.company?.name, 'PT Sinergi');
      expect(user.company?.latitude, -6.175);
      expect(user.employee?.departement?.name, 'Produksi');
      expect(user.employee?.jobPosition?.name, 'Operator');
      expect(user.employee?.signDate, DateTime(2021, 3, 1));
      expect(user.details?.phone, '08120000000');
      expect(user.address?.city, 'Bandung');
      expect(user.salaries?.basicSalary, 5000000);
      expect(user.families?.first.fullname, 'Siti');

      final education = user.formalEducations!.single;

      expect(education.score, 8.1);
      // The screen only ever formats the year, so a year is a faithful date.
      expect(education.start, DateTime(2010));
      expect(education.finish, DateTime(2013));

      expect(user.workExperiences!.single.start, DateTime(2014));
    });
  });

  group('shapes that used to crash the screen', () {
    test('a flattened company is ignored, not fed to Company.fromJson', () {
      // The exact `/auth/me` payload. This is the reported exception.
      final user = User.fromJson({
        'id': 1,
        'name': 'Budi',
        'company': 'PT Sinergi',
        'departement': 'Produksi',
        'job_position': 'Operator',
      });

      expect(user.name, 'Budi');
      // Absent rather than fatal. A screen that shows one blank field beats an
      // app that will not open.
      expect(user.company, isNull);
    });

    test('an employee whose department is a name is ignored, not fatal', () {
      final user = User.fromJson({
        'id': 1,
        'employee': {'user_id': 1, 'departement': 'Produksi'},
      });

      expect(user.employee, isNotNull);
      expect(user.employee?.departement, isNull);
    });

    test('an empty record answers rather than throws', () {
      // Half a workforce has no family, education or employment row yet.
      final user = User.fromJson(const {});

      expect(user.id, isNull);
      expect(user.company, isNull);
      expect(user.employee, isNull);
      expect(user.families, isEmpty);
      expect(user.formalEducations, isEmpty);
    });

    test(
      'rows missing the ids the model declared do not take the list down',
      () {
        // `json['id'] as int` on an absent key threw, and one malformed row cost
        // the whole screen rather than one row.
        final user = User.fromJson({
          'formal_educations': [
            {'institution': 'SMKN 1'},
          ],
        });

        expect(user.formalEducations!.single.institution, 'SMKN 1');
        expect(user.formalEducations!.single.id, 0);
      },
    );
  });
}
