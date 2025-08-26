import 'package:esas/app/widgets/views/custom_bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Import intl for date formatting

import '../controllers/notification_controller.dart';

class NotificationView extends StatelessWidget {
  final controller = Get.put(NotificationController());

  NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    // Access Theme data once at the beginning of the build method
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        // Tampilkan dialog konfirmasi saat tombol kembali ditekan
        showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keluar Aplikasi'),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari aplikasi?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(false), // Tutup dialog
                child: const Text('Tidak'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(true), // Keluar dari aplikasi
                child: const Text('Ya'),
              ),
            ],
          ),
        ).then((value) {
          if (value == true) {
            SystemNavigator.pop();
          }
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Notifikasi'), // Apply theme to title
          centerTitle: true,
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            ); // Use primary color for loading
          }

          // Show a message if there are no notifications
          if (controller.notifications.isEmpty && !controller.hasMore.value) {
            return Center(
              child: Text(
                'Tidak ada notifikasi.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ), // Use onSurfaceVariant for greyish text
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => controller.refreshNotifications(),
            color: colorScheme.primary, // Color of the refresh indicator itself
            backgroundColor: colorScheme
                .surfaceContainerHighest, // Background of the refresh indicator
            child: ListView.builder(
              controller: controller.scrollController,
              itemCount:
                  controller.notifications.length +
                  (controller.isMoreLoading.value ? 1 : 0),
              itemBuilder: (context, index) {
                // Show loading indicator at the bottom
                if (index == controller.notifications.length) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    ), // Use primary color for loading
                  );
                }

                final notif = controller.notifications[index];
                final bool isRead = notif.readAt != null;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ), // Increased margin for better spacing
                  elevation: 0, // Slightly more elevation for definition
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ), // Rounded corners for cards
                  color: isRead
                      ? colorScheme.surface
                      : colorScheme
                            .primary, // Use themed colors for read/unread state
                  child: InkWell(
                    // Use InkWell for splash effect on tap
                    onTap: () {
                      controller.markAsRead(notif.id);
                    },
                    borderRadius: BorderRadius.circular(
                      12,
                    ), // Match card border radius
                    child: Padding(
                      // Add padding inside ListTile to give more space
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        leading: Icon(
                          isRead
                              ? Icons.mark_email_read_outlined
                              : Icons
                                    .mark_email_unread_outlined, // Outlined icons often look cleaner
                          color: isRead
                              ? colorScheme.onSurfaceVariant
                              : colorScheme
                                    .onPrimaryContainer, // Themed icon colors
                          size: 28, // Slightly larger icon
                        ),
                        title: Text(
                          notif.data.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            color: isRead
                                ? colorScheme.onSurfaceVariant
                                : colorScheme
                                      .onPrimaryContainer, // Themed text colors
                          ),
                        ),
                        subtitle: Text(
                          notif.data.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: isRead
                                ? colorScheme.onSurfaceVariant.withAlpha(29)
                                : colorScheme.onPrimaryContainer.withAlpha(
                                    29,
                                  ), // Themed text colors
                          ),
                        ),
                        trailing: Text(
                          _formatNotificationTime(notif.createdAt),
                          style: textTheme.bodySmall?.copyWith(
                            color: isRead
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onPrimaryContainer,
                          ), // Themed time text
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
        bottomNavigationBar: CustomBottomNavBar(),
      ),
    );
  }

  // Helper function to format time
  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} detik lalu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      // For older notifications, display full date
      return DateFormat('dd MMM yyyy').format(dateTime);
    }
  }
}
