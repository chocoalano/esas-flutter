import 'package:esas/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/activity_controller.dart';

class ActivityView extends GetView<ActivityController> {
  const ActivityView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivitas'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Get.offAllNamed(Routes.HOME),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.lists.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.lists.isEmpty) {
          return Center(
            child: Text(
              'Tidak ada aktivitas.',
              style: theme.textTheme.bodyMedium,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.resetAndFetch,
          child: ListView.builder(
            controller: controller.scrollController,
            itemCount: controller.lists.length + 1,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              if (index < controller.lists.length) {
                final item = controller.lists[index];
                return _buildActivityCard(item, theme);
              } else {
                return Obx(() {
                  if (controller.isLoadMore.value) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                });
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildActivityCard(dynamic item, ThemeData theme) {
    final payload = item.payload;
    final name = payload['name'] ?? '-';
    final nip = payload['nip'] ?? '-';
    final email = payload['email'] ?? '-';
    final deviceId = payload['device_id'] ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _badge(
                  item.action.toUpperCase(),
                  theme.colorScheme.primary,
                  theme,
                ),
                const SizedBox(width: 8),
                _badge(item.method, theme.colorScheme.secondary, theme),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text('NIP: $nip\nEmail: $email', style: theme.textTheme.bodySmall),

            const SizedBox(height: 12),
            _iconText(Icons.devices_outlined, 'Device: $deviceId', theme),
            _iconText(Icons.wifi, 'IP: ${item.ipAddress}', theme),
            const SizedBox(height: 8),
            _iconText(Icons.access_time, formatDateTime(item.createdAt), theme),
            _iconText(Icons.link, item.url, theme),

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                onPressed: () {
                  Future.delayed(Duration.zero, () {
                    Get.defaultDialog(
                      title: "Payload",
                      backgroundColor: theme.colorScheme.surface,
                      content: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            payload.toString(),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                      confirm: TextButton(
                        onPressed: () => Get.back(),
                        child: const Text("Tutup"),
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Lihat Payload'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconText(IconData icon, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.iconTheme.color?.withAlpha(27)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
