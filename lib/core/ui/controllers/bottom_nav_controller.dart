import 'package:get/get.dart';

/// The five-tab bottom bar's selection and navigation.
///
/// The destinations are injected rather than written here. `core/` sits below
/// `features/` and may not import it, so hardcoding `'/home'`, `'/attendance'`
/// … meant the tab bar held a second, unchecked copy of the route table — the
/// literals P6-6 warns about. `InitialBinding` supplies the real constants, and
/// `test/core/ui/bottom_nav_controller_test.dart` pins the order.
class BottomNavController extends GetxController {
  BottomNavController({required List<String> destinations})
    : _destinations = destinations;

  /// One route path per tab, in tab order.
  final List<String> _destinations;

  final currentIndex = 0.obs;

  void changeIndex(int index) {
    if (index < 0 || index >= _destinations.length) return;

    currentIndex.value = index;
    Get.offAllNamed(_destinations[index]);
  }
}
