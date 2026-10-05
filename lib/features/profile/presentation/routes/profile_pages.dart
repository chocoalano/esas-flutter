import 'package:get/get.dart';

import '../../../auth/presentation/bindings/auth_bindings.dart';
import '../../../auth/presentation/views/change_password_view.dart';
import '../bindings/profile_bindings.dart';
import '../views/profile_bug_report_view.dart';
import '../views/profile_education_view.dart';
import '../views/profile_experience_view.dart';
import '../views/profile_family_view.dart';
import '../views/profile_payroll_view.dart';
import '../views/profile_personal_view.dart';
import '../views/profile_view.dart';
import '../views/profile_worked_view.dart';
import 'profile_routes.dart';

/// The profile feature's slice of the route table.
///
/// `/profile/change-password` is registered here with auth's view and binding.
/// See [ProfileRoutes.changePassword].
class ProfilePages {
  const ProfilePages._();

  static final List<GetPage> pages = [
    GetPage(
      name: ProfileRoutes.profile,
      page: () => ProfileView(),
      binding: ProfileBinding(),
      transition: Transition.noTransition,
      children: [
        GetPage(
          name: ProfileRoutes.personalSegment,
          page: () => const ProfilePersonalView(),
          binding: ProfilePersonalBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: ProfileRoutes.workedSegment,
          page: () => const ProfileWorkedView(),
          binding: ProfileWorkedBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: ProfileRoutes.familySegment,
          page: () => const ProfileFamilyView(),
          binding: ProfileFamilyBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: ProfileRoutes.educationSegment,
          page: () => const ProfileEducationView(),
          binding: ProfileEducationBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: ProfileRoutes.experienceSegment,
          page: () => const ProfileExperienceView(),
          binding: ProfileExperienceBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: ProfileRoutes.payrollSegment,
          page: () => const ProfilePayrollView(),
          binding: ProfilePayrollBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: ProfileRoutes.changePasswordSegment,
          page: () => const ChangePasswordView(),
          binding: ChangePasswordBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: ProfileRoutes.bugReportSegment,
          page: () => const ProfileBugReportView(),
          binding: ProfileBugReportBinding(),
          transition: Transition.noTransition,
        ),
      ],
    ),
  ];
}
