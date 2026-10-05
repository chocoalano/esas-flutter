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
}
