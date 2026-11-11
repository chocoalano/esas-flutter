import 'package:get/get.dart';

/// The five-tab bottom bar's selection and navigation.
///
/// The destinations are injected rather than written here. `core/` sits below
/// `features/` and may not import it, so hardcoding `'/home'`, `'/attendance'`
/// … meant the tab bar held a second, unchecked copy of the route table — the
/// literals P6-6 warns about. `InitialBinding` supplies the real constants, and
/// `test/core/ui/bottom_nav_controller_test.dart` pins the order.
class BottomNavController extends GetxController {
  BottomNavController({
    required List<String> destinations,
    List<String> resetRoutes = const [],
  }) : _destinations = destinations,
       _resetRoutes = resetRoutes;

  /// One route path per tab, in tab order.
  final List<String> _destinations;

  /// Routes outside a session — login, splash, setup. Reaching one resets the
  /// lit tab, so the next session starts on the home tab (UI-01).
  final List<String> _resetRoutes;

  final currentIndex = 0.obs;

  /// Incremented when the already-active tab is tapped again. Screens listen
  /// to this via `ever()` to scroll their primary list back to the top without
  /// a full page rebuild.
  final scrollToTopSignal = 0.obs;

  /// Preferred tap handler for the bottom bar.
  ///
  /// Re-tapping the active tab emits [scrollToTopSignal] instead of
  /// re-navigating. Tapping a different tab delegates to [changeIndex].
  void onTabTapped(int index) {
    if (index < 0 || index >= _destinations.length) return;
    if (index == currentIndex.value) {
      scrollToTopSignal.value++;
      return;
    }
    changeIndex(index);
  }

  void changeIndex(int index) {
    if (index < 0 || index >= _destinations.length) return;

    currentIndex.value = index;
    Get.offAllNamed(_destinations[index]);
  }

  /// Light the tab [route] belongs to (UI-01, HOME-13).
  ///
  /// Called on every route change. The index used to change only when the bar
  /// itself was tapped, so a tab opened another way — the bell, the avatar, a
  /// shortcut on the home screen — left the wrong tab lit. A screen inside a
  /// tab (`/permit/list`) lights its tab; a screen outside all of them leaves
  /// the lit tab alone.
  void syncWith(String route) {
    if (_resetRoutes.contains(route)) {
      currentIndex.value = 0;
      return;
    }

    var best = -1;
    var bestLength = -1;

    for (var i = 0; i < _destinations.length; i++) {
      final destination = _destinations[i];
      final matches = route == destination || route.startsWith('$destination/');

      if (matches && destination.length > bestLength) {
        best = i;
        bestLength = destination.length;
      }
    }

    if (best >= 0) currentIndex.value = best;
  }
}
