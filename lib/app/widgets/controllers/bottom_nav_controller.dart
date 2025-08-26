// lib/app/controllers/bottom_nav_controller.dart
import 'package:get/get.dart';

class BottomNavController extends GetxController {
  final currentIndex = 0.obs;

  void changeIndex(int index) {
    currentIndex.value = index;

    // Navigasi GetX sesuai index
    switch (index) {
      case 0:
        Get.offAllNamed('/home');
        break;
      case 1:
        Get.offAllNamed('/attendance');
        break;
      case 2:
        Get.offAllNamed('/permit');
        break;
      case 3:
        Get.offAllNamed('/notification');
        break;
      case 4:
        Get.offAllNamed('/profile');
        break;
    }
  }
}
