import 'package:get/get.dart';

import '../bindings/mtms_bindings.dart';
import '../views/mtms_report_views.dart';
import 'mtms_routes.dart';

class MtmsPages {
  const MtmsPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: MtmsRoutes.reports,
      page: () => const MtmsReportListView(),
      binding: MtmsReportListBinding(),
    ),
    GetPage(
      name: MtmsRoutes.reportCreate,
      page: () => const MtmsReportCreateView(),
      binding: MtmsReportCreateBinding(),
    ),
  ];
}
