import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_inline_notice.dart';
import '../../../../core/ui/components/app_skeleton.dart';
import '../../data/models/itms_ticket.dart';
import '../controllers/itms_ticket_detail_controller.dart';
import 'itms_ticket_view_helpers.dart';

/// One IT ticket as its requester may see it (FUNC-D04): where it stands,
/// what IT reported, and when each step happened. Who handled it and the
/// technician's notes are not shown.
class ItmsTicketDetailView extends GetView<ItmsTicketDetailController> {
  const ItmsTicketDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Tiket IT')),
      body: Obx(() {
        final ticket = controller.ticket.value;
        final error = controller.error.value;

        if (controller.isLoading.value && ticket == null) {
          return const AppSkeletonPulse(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppSkeleton(height: 220),
            ),
          );
        }

        if (error != null && ticket == null) {
          return AppErrorState(
            title: error.status == 404
                ? 'Tiket tidak ditemukan'
                : 'Gagal memuat tiket',
            message: error.status == 404
                ? 'Tiket ini tidak ada atau bukan milik Anda.'
                : error.message,
            onRetry: error.status == 404 ? null : controller.load,
          );
        }

        if (ticket == null) return const SizedBox.shrink();

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Header(ticket: ticket),
              const SizedBox(height: 12),
              ..._outcome(ticket),
              _Timeline(ticket: ticket),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _outcome(ItmsTicket ticket) {
    final notes = ticket.resolutionNotes?.trim();
    final waiting = ticket.waitingReason?.trim();

    return [
      if (ticket.status == 'resolved')
        const AppInlineNotice(
          tone: AppNoticeTone.info,
          message:
              'Petugas IT melaporkan tiket ini selesai. Bila masalah belum '
              'teratasi, laporkan tiket baru dan sebutkan nomor tiket ini.',
        )
      else if (ticket.status == 'waiting' && waiting != null && waiting != '')
        AppInlineNotice(
          tone: AppNoticeTone.warning,
          message: 'Sedang menunggu: $waiting',
        )
      else if (!ticket.isClosed)
        AppInlineNotice(
          tone: AppNoticeTone.neutral,
          message: switch ((ticket.isAssigned, ticket.assigneeName)) {
            (true, final String name) => 'Ditangani oleh: $name',
            (true, null) => 'Sudah ditangani petugas IT.',
            (false, _) => 'Menunggu penugasan',
          },
        ),
      const SizedBox(height: 12),
      if (notes != null && notes != '') ...[
        AppCard(
          child: _Section(title: 'Hasil penyelesaian', body: notes),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ticket});

  final ItmsTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = ticket.description?.trim();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('TKT-${ticket.id}', style: theme.textTheme.labelMedium),
              AppBadge(
                label: ticket.statusLabel,
                tone: itmsStatusTone(ticket.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(ticket.subject, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Layanan: ${ticket.serviceName ?? 'IT Helpdesk'}',
            style: theme.textTheme.bodySmall,
          ),
          if (ticket.assigneeName case final name?)
            Text('Petugas IT: $name', style: theme.textTheme.bodySmall),
          if (description != null && description != '') ...[
            const SizedBox(height: 12),
            _Section(title: 'Uraian', body: description),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(body, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.ticket});

  final ItmsTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = <(String, String?)>[
      ('Dilaporkan', ticket.createdAt),
      ('Ditinjau tim IT', ticket.triagedAt),
      ('Ditugaskan ke petugas', ticket.assignedAt),
      ('Mulai dikerjakan', ticket.startedAt),
      ('Menunggu', ticket.waitingAt),
      ('Dilaporkan selesai', ticket.resolvedAt),
      ('Ditutup', ticket.closedAt),
    ].where((step) => itmsWhen(step.$2) != null).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Riwayat', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final (label, at) in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 8),
                    child: Icon(Icons.circle, size: 8),
                  ),
                  Expanded(
                    child: Text(
                      '$label — ${itmsWhen(at)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
