import 'package:esas/core/config/env.dart';
import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/features/setup/data/repositories/workspace_repository.dart';
import 'package:esas/features/setup/data/services/workspace_api_service.dart';
import 'package:esas/features/setup/presentation/controllers/setup_controller.dart';
import 'package:esas/features/setup/presentation/views/setup_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('SetupView renders without RenderFlex overflow or unbounded constraints', (tester) async {
    final store = InMemorySecureStore();
    final serverConfig = ServerConfig(store: store);
    final tenantContext = TenantContext(store: store);

    await serverConfig.restore();
    await tenantContext.restore();

    final controller = SetupController(
      repository: WorkspaceRepository(
        serverConfig: serverConfig,
        tenantContext: tenantContext,
        api: WorkspaceApiService(
          probe: (url, headers) async => (status: 200, body: null),
        ),
      ),
    );

    Get.put<SetupController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        home: const SetupView(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hubungkan ke workspace'), findsOneWidget);
    expect(find.text('Kode workspace'), findsOneWidget);

    // In production mode, Alamat server field is not shown
    expect(find.text('Alamat server'), findsNothing);

    // Switch to development mode
    controller.selectEnvironment(AppEnvironment.development);
    await tester.pumpAndSettle();

    // In development mode, Alamat server field appears
    expect(find.text('Alamat server'), findsOneWidget);
    expect(find.text('Emulator (10.0.2.2:8000)'), findsOneWidget);

    Get.reset();
  });
}
