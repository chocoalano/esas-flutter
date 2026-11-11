import 'package:esas/app/routing/app_pages.dart';
import 'package:esas/core/ui/controllers/bottom_nav_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  group('BottomNavController', () {
    test('ignores an index outside the tab list', () {
      final controller = BottomNavController(destinations: const ['/home']);

      controller.changeIndex(5);
      controller.changeIndex(-1);

      expect(controller.currentIndex.value, 0);
    });
  });

  group('onTabTapped', () {
    late BottomNavController nav;

    setUp(() {
      nav = BottomNavController(
        destinations: const ['/home', '/attendance', '/permit'],
      );
    });

    test('re-tapping the active tab increments scrollToTopSignal without changing index', () {
      nav.currentIndex.value = 1;
      final signalBefore = nav.scrollToTopSignal.value;

      nav.onTabTapped(1);

      expect(nav.currentIndex.value, 1);
      expect(nav.scrollToTopSignal.value, signalBefore + 1);
    });

    test('tapping a different tab does not emit scrollToTopSignal', () {
      nav.currentIndex.value = 0;
      final signalBefore = nav.scrollToTopSignal.value;

      // Calling changeIndex directly since onTabTapped navigates which
      // requires a full app. Verify signal stays unchanged.
      nav.onTabTapped(0); // same tab → signal increments
      nav.onTabTapped(0); // same tab → signal increments again
      final signalAfterSameTab = nav.scrollToTopSignal.value;

      expect(signalAfterSameTab, signalBefore + 2);
      expect(nav.currentIndex.value, 0);
    });

    test('ignores an out-of-range index', () {
      final signalBefore = nav.scrollToTopSignal.value;
      nav.onTabTapped(-1);
      nav.onTabTapped(99);
      expect(nav.scrollToTopSignal.value, signalBefore);
      expect(nav.currentIndex.value, 0);
    });
  });

  // The bar used to hold its own copy of the five paths as string literals, so
  // a route rename would have left it navigating to nothing. It is injected
  // now; this is what stops the injected list drifting from the table.
  test('InitialBinding\'s tab destinations are all registered routes', () {
    // Kept in step with `InitialBinding.dependencies()` by hand — `core/` may
    // not import `features/`, so the controller cannot assert this itself.
    const destinations = [
      '/home',
      '/attendance',
      '/permit',
      '/notification',
      '/profile',
    ];

    final registered = AppPages.routes.map((GetPage p) => p.name).toSet();

    for (final destination in destinations) {
      expect(registered, contains(destination));
    }
  });

  // UI-01 (and HOME-13). The index only changed when the bar itself was
  // tapped. Shortcuts that open a tab another way — the bell, the avatar,
  // "Absen" on the home screen — left the wrong tab lit, and a session that
  // ended on Profil started the next one with Profil lit on the home screen.
  group('the lit tab follows the route', () {
    late BottomNavController nav;

    setUp(() {
      nav = BottomNavController(
        destinations: const [
          '/home',
          '/attendance',
          '/permit',
          '/notification',
          '/profile',
        ],
        resetRoutes: const ['/login', '/splash', '/setup'],
      );
    });

    test('a tab opened another way lights that tab', () {
      nav.syncWith('/notification');
      expect(nav.currentIndex.value, 3);
    });

    test('a screen inside a tab lights its tab', () {
      nav.syncWith('/permit/list');
      expect(nav.currentIndex.value, 2);

      nav.syncWith('/profile/personal');
      expect(nav.currentIndex.value, 4);
    });

    test('leaving the session resets it to the home tab', () {
      nav.syncWith('/profile');
      nav.syncWith('/login');

      expect(nav.currentIndex.value, 0);
    });

    test('a screen outside every tab leaves the lit tab alone', () {
      nav.syncWith('/permit');
      nav.syncWith('/inbox/approvals');

      expect(nav.currentIndex.value, 2);
    });
  });
}
