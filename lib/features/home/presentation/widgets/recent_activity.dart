import 'package:esas/app/data/activity/log.m.dart';
import 'package:esas/app/modules/home/controllers/home_controller.dart';
import 'package:esas/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class RecentActivityList extends StatelessWidget {
  final HomeController controller;
  const RecentActivityList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final activities = controller.activityLog;
      if (activities.isEmpty) {
        return Center(
          child: Text(
            'Tidak ada aktivitas terbaru',
            style: theme.textTheme.bodyMedium,
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, __) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          final ActivityLog act = activities[index];

          IconData icon;
          switch (act.action) {
            case 'created':
              icon = Icons.add_circle_outline;
              break;
            case 'updated':
              icon = Icons.edit;
              break;
            case 'deleted':
              icon = Icons.delete_outline;
              break;
            default:
              icon = Icons.info_outline;
          }

          final dateStr = DateFormat('dd MMM yyyy').format(act.createdAt);
          final timeStr = DateFormat('HH:mm').format(act.createdAt);

          return Card(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withAlpha(20),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              title: Text(
                '${_capitalize(act.action)} ${_extractModelName(act.modelType)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                '$dateStr • $timeStr',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180),
                ),
              ),
              onTap: () => Get.offAllNamed(Routes.ACTIVITY),
            ),
          );
        },
      );
    });
  }

  String _capitalize(String s) {
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String _extractModelName(String type) {
    final parts = type.split('\\');
    return parts.isNotEmpty ? parts.last : type;
  }
}
