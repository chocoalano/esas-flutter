import 'package:esas/features/home/presentation/widgets/home_recent_activity.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// HOME-09. A permit's start date is a calendar date. Converting it as an
/// instant onto the workspace clock moved it a day back on a handset east of
/// the workspace — a WITA phone in a WIB workspace showed the 12th as the
/// 11th, while the permits screen said the 12th. Run with
/// `TZ=Asia/Makassar flutter test` to see it on a development machine.
void main() {
  setUpAll(initializeDateFormatting);

  test('a start date is shown as the date it is', () {
    final permit = Permit.fromJson({
      'id': 1,
      'start_date': '2026-11-12',
      'end_date': '2026-11-12',
    });

    expect(homeActivityDateLabel(permit), '12 Nov 2026');
  });
}
