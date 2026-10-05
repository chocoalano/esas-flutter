/// Where the profile feature's screens live in the route table.
///
/// [changePassword] is served by `features/auth`'s view and controller but is
/// reached at `/profile/change-password`, because that is where the employee
/// finds it. The route belongs to profile; the screen belongs to auth.
class ProfileRoutes {
  const ProfileRoutes._();

  static const profile = '/profile';
  static const personal = '$profile$personalSegment';
  static const worked = '$profile$workedSegment';
  static const family = '$profile$familySegment';
  static const education = '$profile$educationSegment';
  static const experience = '$profile$experienceSegment';
  static const payroll = '$profile$payrollSegment';
  static const changePassword = '$profile$changePasswordSegment';
  static const bugReport = '$profile$bugReportSegment';

  static const personalSegment = '/personal';
  static const workedSegment = '/worked';
  static const familySegment = '/family';
  static const educationSegment = '/education';
  static const experienceSegment = '/experience';
  static const payrollSegment = '/payroll';
  static const changePasswordSegment = '/change-password';
  static const bugReportSegment = '/bug-report';
}
