import 'package:esas/features/home/presentation/widgets/shift_track.dart';
import 'package:flutter_test/flutter_test.dart';

/// HOME-01. `wrapMinutes(now - start)` is negative before the shift starts,
/// wraps to almost a day and clamps to 1.0: every morning, before clocking in,
/// the rail was full as if the shift were over.
void main() {
  int at(int h, int m) => h * 60 + m;

  double? progress(String start, String end, int now, {String? timeIn}) =>
      ShiftTrack.progressFor(
        scheduleIn: start,
        scheduleOut: end,
        timeIn: timeIn,
        timeOut: null,
        nowMinutes: now,
      );

  test('before a day shift starts, nothing has elapsed', () {
    expect(progress('08:00', '17:00', at(7, 30)), 0.0);
  });

  test('half way through is half way', () {
    expect(
      progress('08:00', '17:00', at(12, 30), timeIn: '08:00'),
      closeTo(0.5, 0.001),
    );
  });

  test('after the end, still clocked in, it is full', () {
    expect(progress('08:00', '17:00', at(18, 0), timeIn: '08:00'), 1.0);
  });

  test('clocked in early, before the start, nothing has elapsed', () {
    expect(progress('08:00', '17:00', at(7, 45), timeIn: '07:40'), 0.0);
  });

  test('a night shift before it starts is empty', () {
    expect(progress('22:00', '06:00', at(10, 0)), 0.0);
  });

  test('a night shift past midnight is under way', () {
    expect(
      progress('22:00', '06:00', at(2, 0), timeIn: '22:00'),
      closeTo(0.5, 0.001),
    );
  });
}
