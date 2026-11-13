import 'package:esas/app/routing/app_pages.dart';
import 'package:esas/features/ai_chat/presentation/routes/ai_chat_routes.dart';
import 'package:esas/features/gams/presentation/routes/gams_routes.dart';
import 'package:esas/features/inbox/presentation/routes/inbox_routes.dart';
import 'package:esas/features/itms/presentation/routes/itms_routes.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/auth/presentation/routes/device_routes.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/features/notification/presentation/routes/notification_routes.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:esas/features/profile/presentation/routes/profile_routes.dart';
import 'package:esas/features/setup/presentation/routes/setup_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Every route in the table, with nested children resolved to the full path
/// GetX matches on.
Iterable<({String path, GetPage page})> _flatten(
  List<GetPage> pages, [
  String prefix = '',
]) sync* {
  for (final page in pages) {
    final path = '$prefix${page.name}';
    yield (path: path, page: page);
    final children = page.children;
    yield* _flatten(children, path);
  }
}

void main() {
  final routes = _flatten(AppPages.routes).toList();

  group('route table', () {
    // The paths are the contract: they appear in FCM payloads, and an install
    // that updates mid-navigation resolves the string it already had. Phase 6
    // renamed the constants that spell them; this pins the values.
    //
    // `/setup` is the one addition since, and it is deliberate: ADR-0005 §4
    // specified it, nothing implemented it, and one signed binary could
    // therefore only ever serve the workspace compiled into it (CLI-01).
    test('registers exactly the paths the app shipped with', () {
      expect(routes.map((r) => r.path).toSet(), {
        '/splash',
        '/login',
        '/setup',
        '/home',
        '/home/announcement',
        '/home/announcement/detail',
        '/home/activity',
        '/attendance',
        '/attendance/list',
        '/permit',
        '/permit/list',
        '/permit/show',
        '/permit/create',
        '/notification',
        '/profile',
        '/profile/personal',
        '/profile/worked',
        '/profile/family',
        '/profile/education',
        '/profile/experience',
        '/profile/payroll',
        '/profile/change-password',
        '/profile/bug-report',
        // Added with the module registry and the self-service extensions.
        // Each one is a page a tile, a notification or a deep link opens;
        // `registry_routes_test.dart` pins that every advertised tile is here.
        '/schedule',
        '/overtime',
        '/profile/financial',
        '/ai/chat',
        '/gams',
        '/gams/service-requests',
        '/gams/space-reservations',
        '/gams/vehicle-bookings',
        '/gams/visitor-passes',
        // FUNC-D05: every GA request of the requester's, and one opened.
        '/gams/requests',
        '/gams/requests/detail',
        '/itms',
        '/itms/tickets',
        '/itms/catalog',
        '/itms/knowledge',
        // ITMS-01: "Lapor" had nowhere to go but the dashboard it sat on.
        '/itms/tickets/create',
        // FUNC-D04: every ticket of the requester's, and one ticket opened.
        '/itms/tickets/history',
        '/itms/tickets/detail',
        '/inbox/approvals',
        // Mobile Field Operations Phase 2: the worker's assigned tasks, opened
        // whole or from a module tile filtered to that domain.
        '/tasks',
        '/tasks/gams',
        '/tasks/itms',
        '/tasks/mtms',
        // FUNC-D02: an employee's damage reports, and filing one.
        '/mtms/reports',
        '/mtms/reports/create',
        '/tasks/detail',
        // Phase 3 (D-02): the employee's ATK requests and the GA officer's
        // ATK desk.
        '/atk',
        '/atk/create',
        '/atk/detail',
        '/atk/desk',
        '/atk/desk/detail',
        // ADR-D: enrolling this phone for attendance with an HR code.
        '/device/enrollment',
      });
    });

    test('the feature constants resolve to those same paths', () {
      final paths = routes.map((r) => r.path).toSet();

      for (final constant in [
        AuthRoutes.splash,
        AuthRoutes.login,
        SetupRoutes.setup,
        HomeRoutes.home,
        HomeRoutes.announcement,
        HomeRoutes.announcementDetail,
        HomeRoutes.activity,
        AttendanceRoutes.attendance,
        AttendanceRoutes.list,
        PermitRoutes.permit,
        PermitRoutes.list,
        PermitRoutes.show,
        PermitRoutes.create,
        NotificationRoutes.notification,
        ProfileRoutes.profile,
        ProfileRoutes.personal,
        ProfileRoutes.worked,
        ProfileRoutes.family,
        ProfileRoutes.education,
        ProfileRoutes.experience,
        ProfileRoutes.payroll,
        ProfileRoutes.changePassword,
        ProfileRoutes.bugReport,
        ProfileRoutes.financial,
        HomeRoutes.schedule,
        AttendanceRoutes.overtime,
        AiChatRoutes.chat,
        GamsRoutes.gams,
        GamsRoutes.serviceRequests,
        GamsRoutes.spaceReservations,
        GamsRoutes.vehicleBookings,
        GamsRoutes.visitorPasses,
        ItmsRoutes.itms,
        ItmsRoutes.tickets,
        ItmsRoutes.catalog,
        ItmsRoutes.knowledge,
        ItmsRoutes.ticketCreate,
        ItmsRoutes.ticketHistory,
        ItmsRoutes.ticketDetail,
        InboxRoutes.inbox,
        DeviceRoutes.enrollment,
      ]) {
        expect(paths, contains(constant));
      }
    });

    test('no path is registered twice', () {
      final paths = routes.map((r) => r.path).toList();
      expect(paths.length, paths.toSet().length);
    });

    test('opens on the splash screen', () {
      expect(AppPages.initial, AuthRoutes.splash);
    });
  });

  // P6-3. `/permit/create` was wired to `PermitShowBinding`, and the
  // announcement detail route to a copy of `AnnouncementBinding` — both
  // registered a controller belonging to a different screen, and both screens
  // worked only because some other route happened to still be alive (HIGH-01,
  // HIGH-06). Naming is the only signal available without a Get registry, so
  // the convention is the assertion: `XView` is bound by `XBinding`.
  group('route ↔ binding', () {
    test('every route has a binding', () {
      for (final route in routes) {
        expect(
          route.page.binding,
          isNotNull,
          reason: '${route.path} has no binding',
        );
      }
    });

    test('every binding is named for the view it serves', () {
      for (final route in routes) {
        final view = route.page.page().runtimeType.toString();
        final binding = route.page.binding.runtimeType.toString();

        expect(
          binding,
          '${view.replaceAll(RegExp(r'View$'), '')}Binding',
          reason: '${route.path} renders $view but is bound by $binding',
        );
      }
    });
  });
}
