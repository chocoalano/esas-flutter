import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../data/mtms_reports.dart';
import '../controllers/mtms_report_controllers.dart';

MtmsReportsRepository _repository() {
  if (Get.isRegistered<MtmsReportsRepository>()) {
    return Get.find<MtmsReportsRepository>();
  }
  final repo = MtmsReportsRepository(Get.find<ApiClient>());
  Get.put<MtmsReportsRepository>(repo);
  return repo;
}

class MtmsReportListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MtmsReportListController>(
      () => MtmsReportListController(repository: _repository()),
    );
  }
}

class MtmsReportCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MtmsReportCreateController>(
      () => MtmsReportCreateController(repository: _repository()),
    );
  }
}
