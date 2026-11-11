import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/setup/presentation/controllers/setup_controller.dart';
import 'package:esas/features/home/presentation/widgets/home_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// UAT review C3. CORE-05 gave a TLS failure its own code and sentence, but
/// both screens that explain failures checked "no HTTP status" first, and so
/// still told the person to check their connection.
void main() {
  const tls = ApiException(
    'Koneksi aman ke server tidak dapat diverifikasi. Hubungi administrator.',
    code: 'tls_failure',
  );

  test('setup says the certificate, not the connection', () {
    expect(SetupController.explain(tls, 'acme'), tls.message);
  });

  test('the home panel does not call it a lost connection', () {
    expect(homeFailureKindOf(tls), isNot(HomeFailureKind.network));
  });

  test('a real lost connection is still one', () {
    const offline = ApiException('Offline', code: 'network_unreachable');
    expect(homeFailureKindOf(offline), HomeFailureKind.network);
    expect(
      SetupController.explain(offline, 'acme'),
      contains('tidak dapat dihubungi'),
    );
  });
}
