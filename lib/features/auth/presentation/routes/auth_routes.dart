/// Where the auth feature's screens live in the route table.
///
/// A leaf: it imports nothing, so any feature may name an auth destination
/// without dragging auth's views into its own compilation unit.
///
/// **The path strings are the contract.** They appear in FCM payloads and in
/// `BottomNavController`, and an install that is mid-navigation when it updates
/// resolves the old string. Rename the constants freely; never the values.
class AuthRoutes {
  const AuthRoutes._();

  static const splash = '/splash';
  static const login = '/login';
}
