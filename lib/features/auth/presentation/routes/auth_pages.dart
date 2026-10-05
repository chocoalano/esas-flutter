import 'package:get/get.dart';

import '../bindings/auth_bindings.dart';
import '../views/login_view.dart';
import '../views/splash_view.dart';
import 'auth_routes.dart';

/// The auth feature's slice of the route table.
///
/// Every page names the binding that registers *its own* controller. That
/// invariant is what HIGH-01 broke, and `test/app/routing/app_pages_test.dart`
/// pins it for the whole table.
class AuthPages {
  const AuthPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: AuthRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: AuthRoutes.login,
      page: () => const LoginView(),
      binding: LoginBinding(),
      transition: Transition.noTransition,
    ),
  ];
}
