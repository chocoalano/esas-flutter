class ItmsRoutes {
  const ItmsRoutes._();

  static const itms = '/itms';
  static const tickets = '$itms/tickets';
  static const catalog = '$itms/catalog';
  static const knowledge = '$itms/knowledge';

  /// Filing a ticket (ITMS-01). "Lapor" used to open the dashboard it sat on.
  static const ticketCreate = '$tickets/create';

  /// Every ticket of the requester's, finished ones included (FUNC-D04).
  static const ticketHistory = '$tickets/history';

  /// One ticket; the argument is its id.
  static const ticketDetail = '$tickets/detail';
}
