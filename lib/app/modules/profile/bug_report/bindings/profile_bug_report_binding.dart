import 'package:get/get.dart';

import '../controllers/profile_bug_report_controller.dart';

class ProfileBugReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileBugReportController>(
      () => ProfileBugReportController(),
    );
  }
}
