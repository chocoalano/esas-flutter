import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/presentation/controllers/splash_controller.dart';
import 'package:esas/features/auth/presentation/views/splash_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthRepository auth;
  late ServerConfig serverConfig;
  late TenantContext tenantContext;
  late SplashController controller;

  setUp(() async {
    auth = _MockAuthRepository();
    when(() => auth.restoreSession())
        .thenAnswer((_) async => SessionState.absent);

    final store = InMemorySecureStore();
    serverConfig = ServerConfig(store: store);
    tenantContext = TenantContext(store: store);

    await serverConfig.save(
      domain: 'https://hrms.example.com',
      subdomainMode: true,
    );
    await tenantContext.remember('acme');

    Get.testMode = true;

    controller = SplashController(
      authRepository: auth,
      localStorage: InMemoryLocalStorage(),
      serverConfig: serverConfig,
      tenantContext: tenantContext,
    );
    Get.put<SplashController>(controller);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
      'renders Zero-Trust Enterprise brand, telemetry, and trust badges',
      (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: SplashView(),
      ),
    );

    // Top Status Header
    expect(find.text('ZERO-TRUST NODE VERIFIED'), findsOneWidget);
    expect(find.text('TLS 1.3'), findsOneWidget);

    // Center Hero Brand Identity
    expect(find.text('ABSENSAS'), findsOneWidget);
    expect(find.text('WORKFORCE OPERATING SYSTEM'), findsOneWidget);
    expect(
      find.text('Enterprise Edition v4.8.2 • ISO 27001 Certified'),
      findsOneWidget,
    );

    // Dynamic Initialization & Telemetry
    expect(
      find.text('Autentikasi terenkripsi siap. Membuka sesi...'),
      findsOneWidget,
    );
    expect(find.text('HOST: id-cgk-hcm-04'), findsOneWidget);
    expect(find.text('LATENCY: 14ms'), findsOneWidget);

    // Footer Legal & Trust Badges
    expect(find.text('✓ Bank-Grade AES-256'), findsOneWidget);
    expect(find.text('✓ BSSN Compliant'), findsOneWidget);
    expect(find.text('✓ FIPS 140-3'), findsOneWidget);
    expect(
      find.text('PT Absensas Teknologi Indonesia Tbk • All Rights Reserved'),
      findsOneWidget,
    );
  });

  testWidgets('tapping screen triggers immediate onIntroEnd navigation',
      (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: SplashView(),
      ),
    );

    // Tap on the splash screen
    await tester.tap(find.text('ABSENSAS'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify session decision was resolved
    expect(controller.isLoading.value, isFalse);
  });
}
