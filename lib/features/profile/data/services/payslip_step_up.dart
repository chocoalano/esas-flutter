import '../../../../core/network/api_exception.dart';

/// Payslip step-up (WP-01 Final, G5): pay is read only shortly after the
/// person re-entered their password. The server decides; this only knows the
/// codes it answers with and keeps the view grant it handed out.
abstract final class PayslipStepUp {
  static const view = 'payslip.view';
  static const download = 'payslip.download';

  static const _asks = {
    'payslip_step_up_required',
    'payslip_step_up_expired',
    'payslip_step_up_invalid',
    'payslip_step_up_used',
  };

  /// Whether a refusal is the server asking for the password.
  static bool asks(ApiException error) =>
      error.status == 403 && _asks.contains(error.code);
}

/// Asks the person for their password; null when they cancel.
typedef PayslipPasswordPrompt = Future<String?> Function();

/// The `payslip.view` grant, in memory only and only for the minutes the
/// server gave it. Never written to storage: it is bound to this sign-in on
/// the server, and a stale one is simply refused and asked for again.
class PayslipGrantCache {
  PayslipGrantCache();

  static final PayslipGrantCache instance = PayslipGrantCache();

  String? _grant;
  DateTime? _expiresAt;

  String? get viewGrant {
    final grant = _grant;
    final expiresAt = _expiresAt;
    if (grant == null || expiresAt == null) return null;
    final margin = expiresAt.subtract(const Duration(seconds: 10));
    return DateTime.now().isBefore(margin) ? grant : null;
  }

  void remember(String grant, DateTime expiresAt) {
    _grant = grant;
    _expiresAt = expiresAt;
  }

  void clear() {
    _grant = null;
    _expiresAt = null;
  }
}
