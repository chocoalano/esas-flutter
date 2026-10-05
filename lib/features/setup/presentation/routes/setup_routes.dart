/// Where the setup feature's screen lives in the route table.
///
/// A leaf: it imports nothing, so splash and profile can send somebody here
/// without dragging the setup view into their own compilation unit.
class SetupRoutes {
  const SetupRoutes._();

  static const setup = '/setup';
}
