import 'package:esas/app/data/Notification/notification.m.dart';
import 'package:esas/app/services/api_provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart'; // For ScrollController
import 'package:get/get.dart';

class NotificationController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  final notifications = <NotificationModel>[].obs;
  final isLoading = false.obs; // State for initial loading (first page)
  final isMoreLoading = false.obs; // State for loading more (pagination)
  final hasMore = true.obs; // Indicates if there are more pages to load

  final scrollController = ScrollController();

  int currentPage = 1; // Renamed 'page' to 'currentPage' for clarity
  final int pageSize = 10; // Renamed 'limit' to 'pageSize' for clarity

  @override
  void onInit() {
    super.onInit();
    fetchNotifications(); // Initial fetch

    scrollController.addListener(() {
      // Check if user is near the end of the scroll and not already loading more
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent *
                  0.9 && // Load when 90% scrolled
          !isMoreLoading.value &&
          hasMore.value) {
        fetchNotifications(isLoadMore: true);
      }
    });
  }

  Future<void> fetchNotifications({bool isLoadMore = false}) async {
    // Prevent fetching if already loading or no more data
    if (isLoading.value || isMoreLoading.value) return;
    if (isLoadMore && !hasMore.value) return;

    if (isLoadMore) {
      isMoreLoading.value = true;
    } else {
      isLoading.value = true;
      currentPage = 1; // Reset page for initial fetch
      hasMore.value = true; // Assume there's more data for a new fetch
      notifications.clear(); // Clear existing data for a fresh fetch
    }

    try {
      final String url =
          '/general-module/notifications?page=$currentPage&limit=$pageSize';

      if (kDebugMode) debugPrint('Fetching notifications from URL: $url');

      final response = await _apiProvider.get(url);

      if (response.statusCode == 200) {
        final List<dynamic>? responseData = response.body['data'];

        if (responseData != null && responseData.isNotEmpty) {
          final List<NotificationModel> newItems = responseData
              .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
              .toList();

          notifications.addAll(newItems); // Add new items to the list

          // Check if there are potentially more items
          if (newItems.length < pageSize) {
            hasMore.value = false; // No more data to load
          } else {
            hasMore.value = true; // There might be more data
            currentPage++; // Increment page for next load more
          }
        } else {
          // If 'data' is null or empty, assume no more data
          hasMore.value = false;
          if (kDebugMode) {
            debugPrint('API response "data" field is null or empty.');
          }
        }
      } else {
        // Handle API error response
        // Assuming showApiError is a utility function in ApiProvider or elsewhere
        // Get.snackbar('Error', 'Failed to load notifications: ${response.body['message'] ?? 'Unknown error'}');
        if (kDebugMode) {
          debugPrint('API Error: ${response.statusCode} - ${response.body}');
        }
        // If an error occurs during loadMore, reset page if needed
        if (isLoadMore && currentPage > 1) {
          currentPage--;
        }
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      // Show a user-friendly message
      Get.snackbar('Error', 'Gagal memuat notifikasi. Silakan coba lagi.');
      // If an error occurs during loadMore, reset page if needed
      if (isLoadMore && currentPage > 1) {
        currentPage--;
      }
    } finally {
      isLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      // Optimistically update UI
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && notifications[index].readAt == null) {
        final originalNotification = notifications[index];
        // Create a copy with updated readAt
        notifications[index] = NotificationModel(
          id: originalNotification.id,
          type: originalNotification.type,
          notifiableType: originalNotification.notifiableType,
          notifiableId: originalNotification.notifiableId,
          data: originalNotification.data,
          readAt: DateTime.now(), // Mark as read now
          createdAt: originalNotification.createdAt,
          updatedAt: DateTime.now(), // Update updated_at
          notifiable: originalNotification.notifiable,
        );
        notifications.refresh(); // Notify listeners of the change

        // Call API to mark as read
        final response = await _apiProvider.get(
          '/general-module/notifications/$notificationId',
        ); // Assuming POST request with empty body is fine

        if (response.statusCode != 200) {
          // If API call fails, revert UI change (optional but good practice)
          notifications[index] = originalNotification;
          notifications.refresh();
          Get.snackbar(
            'Gagal',
            'Gagal menandai notifikasi sebagai sudah dibaca.',
          );
          if (kDebugMode) {
            debugPrint(
              'Failed to mark notification as read: ${response.statusCode} - ${response.body}',
            );
          }
        } else {
          Get.snackbar('Berhasil', 'Notifikasi ditandai sudah dibaca.');
        }
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      Get.snackbar('Error', 'Terjadi kesalahan saat menandai notifikasi.');
    }
  }

  // Method to refresh notifications (e.g., Pull-to-Refresh)
  Future<void> refreshNotifications() async {
    isLoading.value = true; // Show loading indicator
    currentPage = 1; // Reset page
    hasMore.value = true; // Assume there's more data
    notifications.clear(); // Clear current list
    await fetchNotifications(); // Fetch first page again
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
