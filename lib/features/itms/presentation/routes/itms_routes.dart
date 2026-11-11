class ItmsRoutes {
  const ItmsRoutes._();

  static const itms = '/itms';
  static const tickets = '$itms/tickets';
  static const catalog = '$itms/catalog';
  static const knowledge = '$itms/knowledge';

  /// Filing a ticket (ITMS-01). "Lapor" used to open the dashboard it sat on.
  static const ticketCreate = '$tickets/create';
}
