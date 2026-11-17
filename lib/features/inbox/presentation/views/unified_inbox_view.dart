import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../../../../core/ui/dialogs/app_dialog.dart';
import '../../data/models/approval_task.dart';
import '../controllers/unified_inbox_controller.dart';

class UnifiedInboxView extends GetView<UnifiedInboxController> {
  const UnifiedInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kotak Masuk Persetujuan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // The page, not the decision snackbar on top of it (as GAMS-04).
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter chips
            Obx(
              () => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    _filterChip(
                      'all',
                      'Semua (${controller.tasks.length})',
                      theme,
                      palette,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _filterChip('hrms', 'HRMS', theme, palette),
                    const SizedBox(width: AppSpacing.xs),
                    _filterChip('gams', 'GAMS', theme, palette),
                    const SizedBox(width: AppSpacing.xs),
                    _filterChip('itms', 'ITMS', theme, palette),
                  ],
                ),
              ),
            ),

            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }

                if (controller.error.value != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: palette.danger.foreground,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            controller.error.value!.message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton(
                            onPressed: controller.loadTasks,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final displayList = controller.filteredTasks;
                if (displayList.isEmpty) {
                  return Center(
                    child: Text(
                      'Tidak ada tugas atau permohonan persetujuan yang menunggu.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: controller.loadTasks,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: displayList.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final task = displayList[index];
                      return _TaskCard(
                        task: task,
                        // Asked first, with the facts in view (FUNC-D19):
                        // one tap used to approve.
                        onApprove: () => _confirmApproval(context, task),
                        onReject: () => _promptRejection(context, task),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    String key,
    String label,
    ThemeData theme,
    AppPalette palette,
  ) {
    final isSelected = controller.selectedFilter.value == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: palette.surfaceSubtle,
      side: BorderSide(color: palette.borderSubtle),
      onSelected: (_) => controller.selectedFilter.value = key,
    );
  }

  /// Menolak sebuah tugas, dengan alasan.
  ///
  /// Dulu `Get.defaultDialog`. Tiga hal di sana yang salah secara desain, bukan
  /// hanya gaya: teks tombol putih tetap (`confirmTextColor: Colors.white`) di
  /// atas hijau brand yang di mode gelap adalah hijau terang — 1,9:1;
  /// `TextEditingController` dibuat di dalam fungsi dan tidak pernah dibuang;
  /// dan tombol "Tolak" tetap aktif selagi keputusan terkirim, sehingga ketukan
  /// kedua mengirim keputusan kedua.
  void _promptRejection(BuildContext context, ApprovalTask task) {
    showDialog<void>(
      context: context,
      // Alasan yang sudah diketik, dan keputusan yang mungkin sedang terkirim,
      // hilang bila barrier-nya sempat tersentuh.
      barrierDismissible: false,
      builder: (_) => _RejectTaskDialog(task: task, controller: controller),
    );
  }

  Future<void> _confirmApproval(BuildContext context, ApprovalTask task) async {
    final bool? approved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);

        return AppDialog(
          icon: Icons.check_circle_outline_rounded,
          title: 'Setujui pengajuan?',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Pemohon: ${task.requesterName}'),
              for (final fact in task.facts)
                Text('${fact.label}: ${fact.value}'),
            ],
          ),
          actions: [
            AppDialog.button(
              label: 'Batal',
              primary: false,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppDialog.button(
              label: 'Setujui',
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (approved == true) {
      await controller.decideTask(taskId: task.id, decision: 'approved');
    }
  }
}

/// Alasan penolakan sebuah tugas. Tetap terbuka — dengan alasan yang sudah
/// diketik — sampai keputusannya benar-benar terkirim (FUNC-D19): dulu ia
/// menutup lebih dulu, sehingga pengiriman yang gagal menghilangkan alasannya.
///
/// Sebuah [StatefulWidget] supaya [TextEditingController]-nya punya pemilik
/// yang membuangnya.
class _RejectTaskDialog extends StatefulWidget {
  const _RejectTaskDialog({required this.task, required this.controller});

  final ApprovalTask task;
  final UnifiedInboxController controller;

  @override
  State<_RejectTaskDialog> createState() => _RejectTaskDialogState();
}

class _RejectTaskDialogState extends State<_RejectTaskDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _sending = false;
  String? _problem;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String reason = _reason.text.trim();

    // Sebaris di bawah kolomnya, bukan snackbar "Validasi" di atas dialog:
    // sebuah snackbar adalah overlay di luar rute, dan menutup dialog dengan
    // `Get.back()` selagi ia tampil hanya menutup snackbar-nya (INBOX-01).
    if (reason.isEmpty) {
      setState(() => _problem = 'Alasan penolakan tidak boleh kosong.');
      return;
    }

    setState(() {
      _sending = true;
      _problem = null;
    });

    final bool sent = await widget.controller.decideTask(
      taskId: widget.task.id,
      decision: 'rejected',
      note: reason,
    );

    if (!mounted) return;

    if (sent) {
      Navigator.of(context).pop();
      return;
    }

    // Tetap terbuka, dengan alasan apa adanya; controller sudah menyatakan
    // kegagalannya.
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      tone: AppDialogTone.danger,
      icon: Icons.do_not_disturb_on_outlined,
      title: 'Tolak Pengajuan',
      message: 'Berikan alasan penolakan untuk "${widget.task.title}":',
      busy: _sending,
      content: TextField(
        controller: _reason,
        enabled: !_sending,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        onChanged: (_) {
          if (_problem != null) setState(() => _problem = null);
        },
        decoration: appInputDecoration(
          theme,
          'Alasan Penolakan',
          hintText: 'Alasan penolakan...',
          helperText:
              'Wajib diisi: Berikan alasan yang jelas mengapa tugas atau '
              'pengajuan ini ditolak.',
          helperMaxLines: 2,
        ).copyWith(errorText: _problem),
      ),
      actions: [
        AppDialog.button(
          label: 'Batal',
          primary: false,
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
        ),
        AppDialog.button(
          label: 'Tolak',
          destructive: true,
          busy: _sending,
          onPressed: _sending ? null : _submit,
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onApprove,
    required this.onReject,
  });

  final ApprovalTask task;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final IconData icon = task.isHrms
        ? Icons.badge_outlined
        : task.isGams
        ? Icons.home_repair_service_outlined
        : Icons.confirmation_number_outlined;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.brandSubtle,
                  borderRadius: AppRadii.smAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      task.domainLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (task.createdAt != null)
                Text(
                  task.createdAt!.split('T').first,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            task.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Pemohon: ${task.requesterName}${task.requesterNip != null ? ' (${task.requesterNip})' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
          // The facts to decide on (UX-A08); the bare note only when the
          // server sent none.
          if (task.facts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.tight),
            for (final fact in task.facts)
              Text(
                '${fact.label}: ${fact.value}',
                style: theme.textTheme.bodyMedium,
              ),
          ] else if (task.notes != null && task.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.tight),
            Text(
              task.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (task.detailRoute case final route?)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    Get.toNamed(route, arguments: {'id': task.detailId}),
                child: const Text('Lihat detail'),
              ),
            ),
          // Only where the server says it can be decided here (INBOX-02).
          if (!task.canDecide) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Diputuskan di modul asalnya, bukan dari kotak masuk ini.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!task.canReject)
                  Expanded(
                    child: Text(
                      'Penolakan belum tersedia untuk jenis ini.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: palette.danger.foreground,
                    ),
                    label: Text(
                      'Tolak',
                      style: TextStyle(color: palette.danger.foreground),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: palette.danger.foreground),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Setujui'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
