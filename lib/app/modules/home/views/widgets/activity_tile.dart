import 'package:flutter/material.dart';

class ActivityTile extends StatelessWidget {
  final String title, date, time, status, points;

  const ActivityTile({
    super.key,
    required this.title,
    required this.date,
    required this.time,
    required this.status,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withAlpha(20),
        foregroundColor: theme.colorScheme.primary,
        child: Text(
          title[0].toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(date, style: theme.textTheme.bodySmall),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$status - $points',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
