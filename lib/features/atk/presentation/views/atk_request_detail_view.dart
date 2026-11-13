import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_inline_notice.dart';
import '../../../../core/ui/dialogs/app_dialogs.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../data/models/atk_models.dart';
import '../controllers/atk_request_detail_controller.dart';
import 'atk_view_helpers.dart';

/// One of the employee's ATK requests: what was asked, why it was refused if
/// it was, every handover with who gave it and when, every return — and
/// confirming receipt.
class AtkRequestDetailView extends GetView<AtkRequestDetailController> {
  const AtkRequestDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Permintaan ATK')),
      body: Obx(() {
        final detail = controller.detail.value;
        final error = controller.error.value;

        if (controller.isLoading.value && detail == null) {
          return const AtkDetailSkeleton();
        }

        if (error != null && detail == null) {
          final missing = error.status == 404;
          return AppErrorState(
            title: missing
                ? 'Permintaan tidak ditemukan'
                : 'Gagal memuat permintaan',
            message: missing
                ? 'Permintaan ini tidak ada atau bukan milik Anda.'
                : error.message,
            onRetry: missing ? null : controller.load,
          );
        }

        if (detail == null) return const SizedBox.shrink();

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Header(detail: detail),
              ..._notices(detail),
              const SizedBox(height: 12),
              _Handovers(
                detail: detail,
                controller: controller,
                onAcknowledge: (issue) => _acknowledge(context, issue),
              ),
              if (detail.returns.isNotEmpty) ...[
                const SizedBox(height: 12),
                AtkReturnsSection(
                  returns: detail.returns,
                  unit: detail.unit,
                  issues: detail.issues,
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _notices(AtkRequestDetail detail) {
    final reason = detail.reason?.trim();
    final refused = detail.status == 'rejected' || detail.status == 'cancelled';
    final failure = controller.notice.value;

    return [
      if (failure != null) ...[
        const SizedBox(height: 12),
        AppInlineNotice(message: failure),
      ],
      if (refused && reason != null && reason.isNotEmpty) ...[
        const SizedBox(height: 12),
        AppInlineNotice(
          tone: AppNoticeTone.warning,
          icon: Icons.block_rounded,
          message: 'Alasan ${detail.statusLabel.toLowerCase()}: $reason',
        ),
      ],
      if (detail.awaitsMyConfirmation) ...[
        const SizedBox(height: 12),
        const AppInlineNotice(
          tone: AppNoticeTone.info,
          icon: Icons.inventory_2_outlined,
          message:
              'Menunggu konfirmasi Anda. Konfirmasi setelah barang benar-benar '
              'Anda terima.',
        ),
      ],
    ];
  }

  Future<void> _acknowledge(BuildContext context, AtkHandover issue) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Konfirmasi diterima',
      message: 'Pastikan barang sudah Anda terima',
      confirmLabel: 'Sudah diterima',
      icon: Icons.inventory_2_outlined,
    );
    if (!confirmed) return;

    if (await controller.acknowledge(issue.id)) {
      showSuccessSnackbar('Penerimaan ${issue.number} dikonfirmasi');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final AtkRequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issued = atkIssuedLine(
      detail.issuedQuantity,
      detail.quantity,
      detail.unit,
    );
    final when = atkWhen(detail.createdAt);

    return Semantics(
      container: true,
      label:
          'Permintaan ATK ${detail.number}, '
          '${atkQuantityLine(detail.itemName, detail.quantity, detail.unit)}, '
          'status ${detail.statusLabel}${issued == null ? '' : ', $issued'}',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(detail.number, style: theme.textTheme.labelMedium),
                AppBadge(
                  label: detail.statusLabel,
                  tone: atkStatusTone(detail.status),
                ),
                if (detail.isFullyIssued)
                  const AppBadge(
                    label: 'Diserahkan',
                    tone: AppBadgeTone.success,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              atkQuantityLine(detail.itemName, detail.quantity, detail.unit),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            AtkLine('Lokasi pengambilan', detail.locationName),
            if (issued != null) AtkLine('Penyerahan', issued),
            if (detail.returnedQuantity > 0)
              AtkLine(
                'Dikembalikan',
                '${detail.returnedQuantity} ${detail.unit}',
              ),
            if (when != null) AtkLine('Diajukan', when),
          ],
        ),
      ),
    );
  }
}

class _Handovers extends StatelessWidget {
  const _Handovers({
    required this.detail,
    required this.controller,
    required this.onAcknowledge,
  });

  final AtkRequestDetail detail;
  final AtkRequestDetailController controller;
  final ValueChanged<AtkHandover> onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AtkSection(
      title: 'Penyerahan barang',
      child: detail.issues.isEmpty
          ? Text(
              'Belum ada barang yang diserahkan.',
              style: theme.textTheme.bodySmall,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, issue) in detail.issues.indexed) ...[
                  if (index > 0) const Divider(height: 20),
                  _HandoverTile(
                    issue: issue,
                    unit: detail.unit,
                    controller: controller,
                    onAcknowledge: onAcknowledge,
                  ),
                ],
              ],
            ),
    );
  }
}

class _HandoverTile extends StatelessWidget {
  const _HandoverTile({
    required this.issue,
    required this.unit,
    required this.controller,
    required this.onAcknowledge,
  });

  final AtkHandover issue;
  final String unit;
  final AtkRequestDetailController controller;
  final ValueChanged<AtkHandover> onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issuedAt = atkWhen(issue.issuedAt);
    final receivedAt = atkWhen(issue.receivedAt);

    return Semantics(
      container: true,
      label: [
        'Penyerahan ${issue.number}',
        '${issue.quantity} $unit',
        if (issue.issuedByName case final giver?) 'oleh $giver',
        if (issue.isReceived)
          'sudah diterima'
        else if (issue.canAcknowledge)
          'menunggu konfirmasi Anda',
        if (issue.returnedQuantity > 0)
          'dikembalikan ${issue.returnedQuantity} $unit',
      ].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${issue.number} • ${issue.quantity} $unit',
                style: theme.textTheme.labelLarge,
              ),
              if (issue.isReceived)
                const AppBadge(label: 'Diterima', tone: AppBadgeTone.success)
              else if (issue.canAcknowledge)
                const AppBadge(
                  label: 'Menunggu konfirmasi Anda',
                  tone: AppBadgeTone.warning,
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (issue.issuedByName case final giver?)
            AtkLine('Diserahkan oleh', giver),
          if (issuedAt != null) AtkLine('Waktu penyerahan', issuedAt),
          if (receivedAt != null) AtkLine('Diterima', receivedAt),
          if (issue.returnedQuantity > 0)
            AtkLine('Dikembalikan', '${issue.returnedQuantity} $unit'),
          if (issue.canAcknowledge) ...[
            const SizedBox(height: 8),
            Obx(() {
              final busy = controller.acknowledging.value;
              return AppButton(
                label: 'Konfirmasi diterima',
                icon: Icons.check_rounded,
                busy: busy == issue.id,
                onPressed: busy != null ? null : () => onAcknowledge(issue),
              );
            }),
          ],
        ],
      ),
    );
  }
}
