import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/tenancy/workspace_clock.dart';
import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_skeleton.dart';
import '../../data/models/atk_models.dart';

/// The badge tone for a request status: waiting is info, reserved is brand,
/// refused is danger, withdrawn is neutral.
AppBadgeTone atkStatusTone(String status) => switch (status) {
  'requested' => AppBadgeTone.info,
  'reserved' => AppBadgeTone.brand,
  'rejected' => AppBadgeTone.danger,
  _ => AppBadgeTone.neutral,
};

/// A server timestamp on the workspace's clock, or null.
String? atkWhen(String? iso) {
  final instant = iso == null ? null : DateTime.tryParse(iso);
  if (instant == null) return null;

  final wall = WorkspaceClock.current.wallClock(instant);
  return '${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(wall)} '
      '${WorkspaceClock.current.abbreviation}';
}

/// "Pulpen × 3 pcs".
String atkQuantityLine(String itemName, int quantity, String unit) =>
    '$itemName × $quantity $unit';

/// What has been handed over so far, or null when nothing has.
String? atkIssuedLine(int issued, int quantity, String unit) {
  if (issued <= 0) return null;
  if (quantity > 0 && issued >= quantity) {
    return 'Diserahkan semua ($issued $unit)';
  }
  return 'Diserahkan $issued dari $quantity $unit';
}

/// The placeholder a list shows while its first page loads.
class AtkListSkeleton extends StatelessWidget {
  const AtkListSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: AppSkeleton(
                height: 104,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The placeholder a detail shows while it loads.
class AtkDetailSkeleton extends StatelessWidget {
  const AtkDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonPulse(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeleton(height: 160),
            SizedBox(height: 12),
            AppSkeleton(height: 120),
          ],
        ),
      ),
    );
  }
}

/// A titled card.
class AtkSection extends StatelessWidget {
  const AtkSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// "Riwayat Pengembalian": every return against a request, newest first — how
/// much, why, who recorded it and when. Draws nothing when there is none.
class AtkReturnsSection extends StatelessWidget {
  const AtkReturnsSection({
    super.key,
    required this.returns,
    required this.unit,
    this.issues = const [],
  });

  final List<AtkReturn> returns;
  final String unit;

  /// The request's handovers, to name the one each return came from.
  final List<AtkHandover> issues;

  @override
  Widget build(BuildContext context) {
    if (returns.isEmpty) return const SizedBox.shrink();

    final issueNumbers = {for (final issue in issues) issue.id: issue.number};

    return AtkSection(
      title: 'Riwayat Pengembalian',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The server lists them oldest first.
          for (final (index, entry) in returns.reversed.indexed) ...[
            if (index > 0) const Divider(height: 20),
            _AtkReturnTile(
              entry: entry,
              unit: unit,
              issueNumber: issueNumbers[entry.issueId],
            ),
          ],
        ],
      ),
    );
  }
}

class _AtkReturnTile extends StatelessWidget {
  const _AtkReturnTile({
    required this.entry,
    required this.unit,
    required this.issueNumber,
  });

  final AtkReturn entry;
  final String unit;
  final String? issueNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = '${entry.quantity} $unit';
    final at = atkWhen(entry.returnedAt);
    final reason = entry.reason;

    return Semantics(
      container: true,
      label: [
        'Pengembalian ${entry.number}',
        amount,
        if (reason != null) 'alasan $reason',
        if (entry.returnedByName case final by?) 'dicatat oleh $by',
        ?at,
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.number.isEmpty ? amount : '${entry.number} • $amount',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          if (issueNumber case final number?)
            AtkLine('Dari penyerahan', number),
          if (reason != null) AtkLine('Alasan', reason),
          if (entry.returnedByName case final by?) AtkLine('Dicatat oleh', by),
          if (at != null) AtkLine('Waktu pengembalian', at),
        ],
      ),
    );
  }
}

/// "Label: value", wrapping as one sentence on a narrow screen.
class AtkLine extends StatelessWidget {
  const AtkLine(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: value, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// The "Muat lebih banyak" footer of a paged list, with the reason a later
/// page failed when it did.
class AtkLoadMoreFooter extends StatelessWidget {
  const AtkLoadMoreFooter({
    super.key,
    required this.isLoading,
    required this.onPressed,
    this.error,
  });

  final bool isLoading;
  final VoidCallback onPressed;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error case final message?)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        Center(
          child: TextButton(
            onPressed: isLoading ? null : onPressed,
            child: Text(isLoading ? 'Memuat…' : 'Muat lebih banyak'),
          ),
        ),
      ],
    );
  }
}
