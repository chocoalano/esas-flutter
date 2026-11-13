class AtkRoutes {
  const AtkRoutes._();

  /// "Permintaan ATK Saya": the employee's own office-supply requests.
  static const requests = '/atk';

  /// Asking for ATK. Returns the new request's number to the list.
  static const create = '$requests/create';

  /// One of the employee's requests; the argument is its id.
  static const detail = '$requests/detail';

  /// "Meja ATK": the GA officer's open requests.
  static const desk = '$requests/desk';

  /// One request on the desk; the argument is its id.
  static const deskDetail = '$desk/detail';
}
