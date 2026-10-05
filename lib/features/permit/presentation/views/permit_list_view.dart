import 'package:esas/app/modules/permit/views/widgets/permit_list_item.dart';
import 'package:esas/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Cek path berikut sesuai struktur proyekmu!
import 'package:esas/app/data/Permit/leave_list.m.dart';
import '../controllers/permit_list_controller.dart';

class PermitListView extends GetView<PermitListController> {
  const PermitListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        Get.offAllNamed(Routes.PERMIT);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Obx(
            () => Text(
              controller.appBarTitle.value.isEmpty
                  ? 'Daftar Perizinan'
                  : controller.appBarTitle.value,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Get.offAllNamed(Routes.PERMIT),
          ),
        ),
        body: Obx(() {
          // Loading pertama
          if (controller.isLoading.value && controller.permits.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Kosong
          if (controller.permits.isEmpty && !controller.isLoading.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 80,
                    color: theme.colorScheme.onSurface.withAlpha(29),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat perizinan untuk tipe ini.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(29),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: controller.resetAndFetch,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // List dengan infinite scroll & pull to refresh
          return RefreshIndicator(
            onRefresh: controller.resetAndFetch,
            child: ListView.builder(
              controller: controller.scrollController,
              itemCount:
                  controller.permits.length +
                  (controller.hasMore.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < controller.permits.length) {
                  final Permit permit = controller.permits[index];
                  return PermitListItem(permit: permit, theme: theme);
                } else {
                  // Indikator loading infinite scroll
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: controller.isLoadMore.value
                          ? const CircularProgressIndicator()
                          : const SizedBox.shrink(),
                    ),
                  );
                }
              },
            ),
          );
        }),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Get.offAllNamed(
              Routes.PERMIT_CREATE,
              arguments: controller.permitType.value,
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
