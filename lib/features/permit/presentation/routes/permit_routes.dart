/// Where the permit feature's screens live in the route table.
///
/// Flat, not nested: `/permit/list` and friends are registered as top-level
/// `GetPage`s whose names happen to share a prefix. That is how they have
/// always been registered, and changing it changes the back stack.
class PermitRoutes {
  const PermitRoutes._();

  static const permit = '/permit';
  static const list = '/permit/list';
  static const show = '/permit/show';
  static const create = '/permit/create';
}
