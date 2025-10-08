import 'package:get/get.dart';

import 'bindings/profile_binding.dart';
import 'bug_report/bindings/profile_bug_report_binding.dart';
import 'bug_report/views/profile_bug_report_view.dart';
import 'change_password/bindings/profile_change_password_binding.dart';
import 'change_password/views/profile_change_password_view.dart';
import 'education/bindings/profile_education_binding.dart';
import 'education/views/profile_education_view.dart';
import 'experience/bindings/profile_experience_binding.dart';
import 'experience/views/profile_experience_view.dart';
import 'family/bindings/profile_family_binding.dart';
import 'family/views/profile_family_view.dart';
import 'payroll/bindings/profile_payroll_binding.dart';
import 'payroll/views/profile_payroll_view.dart';
import 'personal/bindings/profile_personal_binding.dart';
import 'personal/views/profile_personal_view.dart';
import 'views/profile_view.dart';
import 'worked/bindings/profile_worked_binding.dart';
import 'worked/views/profile_worked_view.dart';

part 'profile_routes.dart';

class ProfilePages {
  ProfilePages._();
  static final routes = [
    GetPage(
      name: _Paths.PROFILE,
      page: () => ProfileView(),
      binding: ProfileBinding(),
      transition: Transition.noTransition,
      children: [
        GetPage(
          name: _Paths.PROFILE_PERSONAL,
          page: () => const ProfilePersonalView(),
          binding: ProfilePersonalBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: _Paths.PROFILE_WORKED,
          page: () => const ProfileWorkedView(),
          binding: ProfileWorkedBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: _Paths.PROFILE_FAMILY,
          page: () => const ProfileFamilyView(),
          binding: ProfileFamilyBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: _Paths.PROFILE_EDUCATION,
          page: () => const ProfileEducationView(),
          binding: ProfileEducationBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: _Paths.PROFILE_EXPERIENCE,
          page: () => const ProfileExperienceView(),
          binding: ProfileExperienceBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: _Paths.PROFILE_PAYROLL,
          page: () => const ProfilePayrollView(),
          binding: ProfilePayrollBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: _Paths.PROFILE_CHANGE_PASSWORD,
          page: () => const ProfileChangePasswordView(),
          binding: ProfileChangePasswordBinding(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: _Paths.PROFILE_BUG_REPORT,
          page: () => const ProfileBugReportView(),
          binding: ProfileBugReportBinding(),
          transition: Transition.noTransition,
        ),
      ],
    ),
  ];
}
