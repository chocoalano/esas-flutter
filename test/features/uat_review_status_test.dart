import 'package:esas/features/gams/data/models/gams_service_request.dart';
import 'package:esas/features/home/data/models/schedule_calendar.dart';
import 'package:esas/features/itms/data/models/itms_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

/// UAT review: values the server actually sends.
void main() {
  // H4. GAMS-03 / ITMS-01 counted only open requests and tickets as "aktif",
  // but read "finished" as closed or resolved. The backend enums
  // (ServiceRequestStatus, ItmsTicketStatus) also end in `cancelled`.
  test('a cancelled request or ticket is not active', () {
    expect(
      GamsServiceRequest.fromJson({'id': 1, 'status': 'cancelled'}).isClosed,
      isTrue,
    );
    expect(
      ItmsTicket.fromJson({'id': 1, 'status': 'cancelled'}).isClosed,
      isTrue,
    );
    expect(
      ItmsTicket.fromJson({'id': 1, 'status': 'waiting'}).isClosed,
      isFalse,
    );
  });

  // H5. HOME-11 listed spellings the server never sends. DayType is
  // `working` / `rest` / `holiday` (tenancy-app App\Enums\Hrms\Attendance).
  test('the day types the server sends are recognised', () {
    ScheduleCalendarItem day(String type) =>
        ScheduleCalendarItem.fromJson({'date': '2026-11-11', 'day_type': type});

    expect(day('working').isWorkday, isTrue);
    expect(day('rest').isDayOff, isTrue);
    expect(day('holiday').isHoliday, isTrue);
    expect(day('rest').isWorkday, isFalse);
  });
}
