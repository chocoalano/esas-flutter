import 'package:intl/intl.dart';

import '../../../../core/tenancy/workspace_clock.dart';
import '../../../../core/ui/components/app_badge.dart';

/// The badge tone for a ticket status, as the rest of the app colours them:
/// reported-but-not-final is info, finished is success, waiting is warning.
AppBadgeTone itmsStatusTone(String status) => switch (status) {
  'resolved' => AppBadgeTone.info,
  'closed' => AppBadgeTone.success,
  'waiting' => AppBadgeTone.warning,
  'cancelled' => AppBadgeTone.danger,
  'in_progress' || 'assigned' => AppBadgeTone.brand,
  _ => AppBadgeTone.neutral,
};

/// A server timestamp on the workspace's clock, or null.
String? itmsWhen(String? iso) {
  final instant = iso == null ? null : DateTime.tryParse(iso);
  if (instant == null) return null;

  final wall = WorkspaceClock.current.wallClock(instant);
  return '${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(wall)} '
      '${WorkspaceClock.current.abbreviation}';
}
