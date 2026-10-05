import 'package:esas/app/routing/app_pages.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
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
