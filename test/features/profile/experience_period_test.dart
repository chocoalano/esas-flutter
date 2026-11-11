import 'package:esas/features/profile/data/repositories/profile_repository.dart';
import 'package:esas/features/profile/presentation/controllers/profile_tab_controllers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements ProfileRepository {}

/// PROF-05. Work experience periods arrive as years; formatting the DateTime
/// built from one as `dd MMM yyyy` invented a day and a month: "01 Jan 2014".
void main() {
  setUpAll(initializeDateFormatting);

  test('a period known to the year is shown to the year', () {
    final controller = ProfileExperienceController(repository: _Repo());

    expect(
      controller.formatWorkPeriod(DateTime(2014), DateTime(2020)),
      '2014 - 2020',
    );
    expect(controller.formatWorkPeriod(DateTime(2014), null), '2014 - Sekarang');
  });
}
