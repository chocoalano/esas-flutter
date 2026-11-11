import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/components/custom_bottom_navbar.dart';
import 'package:esas/core/ui/controllers/bottom_nav_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// UI-04. A fixed 60 dp overflowed past a text scale of about 2.1 — iOS
/// "Larger Accessibility Sizes" AX3 and up.
void main() {
  tearDown(Get.reset);

  for (final scale in [1.0, 2.35, 3.1]) {
    testWidgets('the bar holds its labels at text scale $scale', (
      tester,
    ) async {
      Get.put(
        BottomNavController(destinations: const ['/a', '/b', '/c', '/d', '/e']),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(bottomNavigationBar: CustomBottomNavBar()),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // A floor, not the whole screen: the first version of this fix let the
      // bar grow to every pixel the Scaffold offered and left the page body
      // with a height of zero.
      final double height = tester
          .getSize(find.byType(CustomBottomNavBar))
          .height;
      expect(height, greaterThanOrEqualTo(60));
      // 60 plus the 1 dp top border — what the fixed box measured too.
      expect(height, lessThanOrEqualTo(scale == 1.0 ? 61 : 200));
    });
  }
}
