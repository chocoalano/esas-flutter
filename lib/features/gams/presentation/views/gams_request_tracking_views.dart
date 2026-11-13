import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/tenancy/workspace_clock.dart';
import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_empty_state.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_inline_notice.dart';
import '../../../../core/ui/components/app_skeleton.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../controllers/gams_request_tracking_controllers.dart';
import '../routes/gams_routes.dart';

AppBadgeTone _tone(String status) => switch (status) {
  'resolved' => AppBadgeTone.info,
  'closed' => AppBadgeTone.success,
  'cancelled' => AppBadgeTone.danger,
  'in_progress' || 'triaged' => AppBadgeTone.brand,
  _ => AppBadgeTone.neutral,
};

String? _when(String? iso) {
  final instant = iso == null ? null : DateTime.tryParse(iso);
  if (instant == null) return null;
  final wall = WorkspaceClock.current.wallClock(instant);
  return '${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(wall)} '
      '${WorkspaceClock.current.abbreviation}';
}

/// All of the employee's GA service requests (FUNC-D05).
class GamsRequestListView extends GetView<GamsRequestListController> {
  const GamsRequestListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Permintaan GA Saya')),
      body: Obx(() {
        final error = controller.error.value;

        if (controller.isLoading.value && controller.requests.isEmpty) {
          return const AppSkeletonPulse(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppSkeleton(height: 220),
            ),
          );
        }
        if (error != null && controller.requests.isEmpty) {
          return AppErrorState(
            title: error.isForbidden
                ? 'Tidak ada akses'
                : 'Gagal memuat permintaan',
            message: error.message,
            onRetry: controller.load,
          );
        }
        if (controller.requests.isEmpty) {
          return const AppEmptyState(
            icon: Icons.home_repair_service_outlined,
            title: 'Belum ada permintaan',
            message: 'Permintaan layanan GA yang Anda ajukan tampil di sini.',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              for (final request in controller.requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    button: true,
                    label:
                        'Permintaan ${request.subject}, ${request.statusLabel}. '
                        'Ketuk untuk melihat detail.',
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Get.toNamed(
                        GamsRoutes.requestDetail,
                        arguments: request.id,
                      ),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  request.number,
                                  style: theme.textTheme.labelMedium,
                                ),
                                AppBadge(
                                  label: request.statusLabel,
                                  tone: _tone(request.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              request.subject,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              [
                                ?request.serviceDefinition,
                                ?_when(request.createdAt),
                              ].join(' • '),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (controller.hasMore.value)
                Center(
                  child: TextButton(
                    onPressed: controller.isLoadingMore.value
                        ? null
                        : controller.loadMore,
                    child: Text(
                      controller.isLoadingMore.value
                          ? 'Memuat…'
                          : 'Muat lebih banyak',
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

/// One GA service request as its requester may see it (FUNC-D05).
class GamsRequestDetailView extends GetView<GamsRequestDetailController> {
  const GamsRequestDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Permintaan GA')),
      body: Obx(() {
        final request = controller.request.value;
        final error = controller.error.value;

        if (controller.isLoading.value && request == null) {
          return const AppSkeletonPulse(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppSkeleton(height: 220),
            ),
          );
        }
        if (error != null && request == null) {
          return AppErrorState(
            title: error.status == 404
                ? 'Permintaan tidak ditemukan'
                : 'Gagal memuat permintaan',
            message: error.status == 404
                ? 'Permintaan ini tidak ada atau bukan milik Anda.'
                : error.message,
            onRetry: error.status == 404 ? null : controller.load,
          );
        }
        if (request == null) return const SizedBox.shrink();

        final note = request.resolutionNote?.trim();
        final steps = <(String, String?)>[
          ('Diajukan', request.submittedAt ?? request.createdAt),
          ('Diperiksa tim GA', request.triagedAt),
          ('Diselesaikan', request.resolvedAt),
          ('Ditutup', request.closedAt),
          ('Dibatalkan', request.cancelledAt),
        ].where((step) => _when(step.$2) != null).toList();

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          request.number,
                          style: theme.textTheme.labelMedium,
                        ),
                        AppBadge(
                          label: request.statusLabel,
                          tone: _tone(request.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(request.subject, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    for (final line in [
                      if (request.serviceDefinition case final s?)
                        'Layanan: $s',
                      if (request.facility case final f?) 'Gedung: $f',
                    ])
                      Text(line, style: theme.textTheme.bodySmall),
                    if (request.description?.trim() case final d?
                        when d.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Keterangan', style: theme.textTheme.labelLarge),
                      Text(d, style: theme.textTheme.bodyMedium),
                    ],
                    if (request.answers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Isian layanan', style: theme.textTheme.labelLarge),
                      for (final entry in request.answers.entries)
                        Text(
                          '${_label(entry.key)}: ${_value(entry.value)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (request.status == 'resolved')
                const AppInlineNotice(
                  tone: AppNoticeTone.info,
                  message: 'Tim GA melaporkan permintaan ini selesai.',
                )
              else if (!request.isClosed)
                const AppInlineNotice(
                  tone: AppNoticeTone.neutral,
                  message: 'Permintaan sedang diproses tim GA.',
                ),
              const SizedBox(height: 12),
              if (note != null && note.isNotEmpty) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hasil penyelesaian',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(note, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (request.canCancel) ...[
                AppButton(
                  label: 'Batalkan permintaan',
                  variant: AppButtonVariant.outlined,
                  onPressed: () async {
                    final done = await confirmGamsCancellation(
                      context,
                      title: 'Batalkan permintaan?',
                      consequence:
                          'Permintaan yang dibatalkan tidak lagi diproses tim '
                          'GA dan tidak dapat dibuka kembali.',
                      onCancel: controller.cancel,
                    );
                    if (done) showSuccessSnackbar('Permintaan dibatalkan.');
                  },
                ),
                const SizedBox(height: 12),
              ],
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Riwayat', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    for (final (label, at) in steps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '$label — ${_when(at)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  static String _label(String key) => key
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static String _value(Object? value) => switch (value) {
    true => 'Ya',
    false => 'Tidak',
    List<dynamic> list => list.join(', '),
    _ => '$value',
  };
}

/// Asks for a reason and withdraws something of the requester's (D-06).
///
/// Says what cancelling means, keeps the reason while the answer is pending,
/// and stays open - reason and all - when it did not go through.
Future<bool> confirmGamsCancellation(
  BuildContext context, {
  required String title,
  required String consequence,
  required Future<String?> Function(String reason) onCancel,
  bool reasonRequired = true,
}) async {
  final done = await showDialog<bool>(
    context: context,
    builder: (_) => _CancelDialog(
      title: title,
      consequence: consequence,
      onCancel: onCancel,
      reasonRequired: reasonRequired,
    ),
  );
  return done == true;
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({
    required this.title,
    required this.consequence,
    required this.onCancel,
    required this.reasonRequired,
  });

  final String title;
  final String consequence;
  final Future<String?> Function(String reason) onCancel;
  final bool reasonRequired;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (widget.reasonRequired && reason.isEmpty) {
      setState(() => _error = 'Tuliskan alasan pembatalan.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final problem = await widget.onCancel(reason);
    if (!mounted) return;
    if (problem == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.consequence),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.reasonRequired
                    ? 'Alasan pembatalan'
                    : 'Alasan pembatalan (opsional)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error case final message?) ...[
              const SizedBox(height: 8),
              AppInlineNotice(message: message),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Kembali'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: Text(_sending ? 'Membatalkan…' : 'Batalkan'),
        ),
      ],
    );
  }
}
