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

  testWidgets('renders brand header, first slide, and action button',
      (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const SplashView(),
      ),
    );

    // Header brand
    expect(find.text('ABSENSAS'), findsOneWidget);
    expect(find.text('Employee Self-Service'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);

    // Slide 1 Content
    expect(find.text('PRESENSI CEPAT'), findsOneWidget);
    expect(find.text('Presensi Akurat & Terverifikasi'), findsOneWidget);
    expect(find.text('Geofencing GPS'), findsOneWidget);

    // Primary action button
    expect(find.text('Lanjutkan'), findsOneWidget);
  });

  testWidgets('swiping or tapping Lanjutkan advances to next slide',
      (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const SplashView(),
      ),
    );

    // Tap Lanjutkan
    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();

    // Slide 2 Content
    expect(find.text('SELF-SERVICE HR'), findsOneWidget);
    expect(find.text('Pengajuan Izin & Cuti Mudah'), findsOneWidget);
    expect(find.text('Cuti & Lembur'), findsOneWidget);

    // Tap Lanjutkan again to reach last slide
    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();

    // Slide 3 Content
    expect(find.text('KOLABORASI TIM'), findsOneWidget);
    expect(find.text('Akses Fleksibel Kapan Saja'), findsOneWidget);
    expect(find.text('Mulai Sekarang'), findsOneWidget);
  });
}
