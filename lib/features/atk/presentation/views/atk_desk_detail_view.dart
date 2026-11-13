import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_empty_state.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_inline_notice.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../../../../core/ui/dialogs/app_dialogs.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../data/models/atk_models.dart';
import '../controllers/atk_desk_detail_controller.dart';
import 'atk_desk_list_view.dart';
import 'atk_view_helpers.dart';

/// One request on the ATK desk: what was asked and by whom, the stock behind
/// it, its handovers, returns and movements — and exactly the actions the
/// server allows the officer right now.
class AtkDeskDetailView extends GetView<AtkDeskDetailController> {
  const AtkDeskDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Meja ATK')),
      body: Obx(() {
        final detail = controller.detail.value;
        final error = controller.error.value;

        if (controller.isLoading.value && detail == null) {
          return const AtkDetailSkeleton();
        }

        if (controller.isDenied && detail == null) {
          return const AppEmptyState(
            icon: Icons.lock_outline_rounded,
            title: atkDeskDeniedMessage,
            message: 'Meja ATK khusus petugas GA.',
          );
        }

        if (error != null && (detail == null || error.status == 404)) {
          final missing = error.status == 404;
          return AppErrorState(
            title: missing
                ? 'Permintaan tidak ditemukan'
                : 'Gagal memuat permintaan',
            message: missing
                ? 'Permintaan ATK ini tidak ada lagi.'
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
              if (controller.notice.value case final message?) ...[
                const SizedBox(height: 12),
                AppInlineNotice(
                  tone: controller.noticeIsConflict.value
                      ? AppNoticeTone.warning
                      : AppNoticeTone.danger,
                  message: message,
                ),
              ],
              const SizedBox(height: 12),
              _Stock(detail: detail),
              const SizedBox(height: 12),
              _Handovers(
                detail: detail,
                controller: controller,
                onReturn: (issue) => _receiveReturn(context, issue),
              ),
              if (detail.returns.isNotEmpty) ...[
                const SizedBox(height: 12),
                AtkReturnsSection(
                  returns: detail.returns,
                  unit: detail.request.unit,
                  issues: detail.issues,
                ),
              ],
              const SizedBox(height: 12),
              _Movements(detail: detail),
            ],
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
        final detail = controller.detail.value;
        final request = detail?.request;
        if (detail == null || request == null || !request.needsAction) {
          return const SizedBox.shrink();
        }
        final busy = controller.submitting.value;

        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (request.allows(AtkDeskAction.issue))
                _ActionSlot(
                  child: AppButton(
                    label: 'Serahkan',
                    icon: Icons.outbox_outlined,
                    busy: busy == AtkDeskAction.issue,
                    onPressed: busy != null
                        ? null
                        : () => _issue(context, detail),
                  ),
                ),
              if (request.allows(AtkDeskAction.reserve))
                _ActionSlot(
                  child: AppButton(
                    label: 'Reservasi',
                    icon: Icons.bookmark_add_outlined,
                    busy: busy == AtkDeskAction.reserve,
                    onPressed: busy != null
                        ? null
                        : () => _reserve(context, detail),
                  ),
                ),
              if (request.allows(AtkDeskAction.reject))
                _ActionSlot(
                  child: AppButton(
                    label: 'Tolak',
                    icon: Icons.block_rounded,
                    variant: AppButtonVariant.outlined,
                    busy: busy == AtkDeskAction.reject,
                    onPressed: busy != null ? null : () => _reject(context),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _reserve(BuildContext context, AtkDeskDetail detail) async {
    final request = detail.request;
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Reservasi barang',
      message:
          'Sisihkan ${atkQuantityLine(request.itemName, request.quantity, request.unit)} '
          'untuk ${request.number}? Stok tersedia akan berkurang.',
      confirmLabel: 'Reservasi',
      icon: Icons.bookmark_add_outlined,
    );
    if (!confirmed) return;

    if (await controller.reserve()) {
      showSuccessSnackbar('Barang direservasi untuk ${request.number}');
    }
  }

  Future<void> _reject(BuildContext context) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AtkRejectDialog(controller: controller),
    );
    if (done == true) showSuccessSnackbar('Permintaan ditolak');
  }

  Future<void> _receiveReturn(BuildContext context, AtkHandover issue) async {
    // A new intent: what the last action ended in no longer applies.
    controller.notice.value = null;
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          AtkReturnDialog(controller: controller, issueId: issue.id),
    );
    if (message != null) showSuccessSnackbar(message);
  }

  Future<void> _issue(BuildContext context, AtkDeskDetail detail) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AtkIssueDialog(controller: controller),
    );
    if (done == true) {
      showSuccessSnackbar('Barang diserahkan. Menunggu konfirmasi penerima.');
    }
  }
}

class _ActionSlot extends StatelessWidget {
  const _ActionSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 8), child: child);
}

/// Rejecting a request: a reason is required, and the dialog stays open —
/// with what was typed — until the server accepts it.
class AtkRejectDialog extends StatefulWidget {
  const AtkRejectDialog({super.key, required this.controller});

  final AtkDeskDetailController controller;

  @override
  State<AtkRejectDialog> createState() => _AtkRejectDialogState();
}

class _AtkRejectDialogState extends State<AtkRejectDialog> {
  final TextEditingController _reason = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = widget.controller;
    final problem = controller.validateReason(_reason.text);
    setState(() => _problem = problem);
    if (problem != null) return;

    final ok = await controller.reject(_reason.text);
    if (!mounted) return;
    // Closed on success, or when the request moved on and rejecting it is no
    // longer allowed; otherwise it stays open with the reason as typed.
    if (ok || !controller.allows(AtkDeskAction.reject)) {
      Navigator.of(context).pop(ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return Obx(() {
      final busy = controller.submitting.value == AtkDeskAction.reject;
      final failure = controller.notice.value;

      return AlertDialog(
        scrollable: true,
        title: const Text('Tolak permintaan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _reason,
              enabled: !busy,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: AtkDeskDetailController.reasonMax,
              decoration: appInputDecoration(
                theme,
                'Alasan penolakan',
                helperText: 'Alasan ini dikirim ke pemohon.',
              ).copyWith(errorText: _problem),
            ),
            if (failure != null) ...[
              const SizedBox(height: 8),
              AppInlineNotice(
                tone: controller.noticeIsConflict.value
                    ? AppNoticeTone.warning
                    : AppNoticeTone.danger,
                message: failure,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          AppButton(
            label: 'Tolak permintaan',
            expand: false,
            busy: busy,
            onPressed: busy ? null : _submit,
          ),
        ],
      );
    });
  }
}

/// Handing over goods: how many, defaulting to what is still owed and never
/// more than that. Stays open with the quantity until the server accepts it.
class AtkIssueDialog extends StatefulWidget {
  const AtkIssueDialog({super.key, required this.controller});

  final AtkDeskDetailController controller;

  @override
  State<AtkIssueDialog> createState() => _AtkIssueDialogState();
}

class _AtkIssueDialogState extends State<AtkIssueDialog> {
  late final TextEditingController _quantity = TextEditingController(
    text: '${widget.controller.detail.value?.remaining ?? 1}',
  );
  String? _problem;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = widget.controller;
    final quantity = int.tryParse(_quantity.text.trim());
    final problem = controller.validateIssueQuantity(quantity);
    setState(() => _problem = problem);
    if (problem != null) return;

    final ok = await controller.issue(quantity);
    if (!mounted) return;
    if (ok || !controller.allows(AtkDeskAction.issue)) {
      Navigator.of(context).pop(ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return Obx(() {
      final busy = controller.submitting.value == AtkDeskAction.issue;
      final failure = controller.notice.value;
      final detail = controller.detail.value;
      final unit = detail?.request.unit ?? '';

      return AlertDialog(
        scrollable: true,
        title: const Text('Serahkan barang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _quantity,
              enabled: !busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: appInputDecoration(
                theme,
                'Jumlah diserahkan',
                helperText: detail == null
                    ? null
                    : 'Sisa ${detail.remaining} $unit • tersedia '
                          '${detail.stock.available} $unit',
              ).copyWith(errorText: _problem),
            ),
            if (failure != null) ...[
              const SizedBox(height: 8),
              AppInlineNotice(
                tone: controller.noticeIsConflict.value
                    ? AppNoticeTone.warning
                    : AppNoticeTone.danger,
                message: failure,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          AppButton(
            label: 'Serahkan barang',
            expand: false,
            busy: busy,
            onPressed: busy ? null : _submit,
          ),
        ],
      );
    });
  }
}

/// Receiving goods back against one handover: how many — all that may still
/// come back by default, never more, never less than one — and why. Stays
/// open, with what was entered, until the server records it.
class AtkReturnDialog extends StatefulWidget {
  const AtkReturnDialog({
    super.key,
    required this.controller,
    required this.issueId,
  });

  final AtkDeskDetailController controller;
  final int issueId;

  @override
  State<AtkReturnDialog> createState() => _AtkReturnDialogState();
}

class _AtkReturnDialogState extends State<AtkReturnDialog> {
  late final TextEditingController _quantity = TextEditingController(
    text: '${_issue?.returnableQuantity ?? 1}',
  );
  final TextEditingController _reason = TextEditingController();
  String? _quantityProblem;
  String? _reasonProblem;

  AtkHandover? get _issue =>
      widget.controller.detail.value?.issueById(widget.issueId);

  int? get _typed => int.tryParse(_quantity.text.trim());

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _step(int delta, int max) {
    final next = ((_typed ?? 0) + delta).clamp(1, max < 1 ? 1 : max);
    final text = '$next';
    _quantity.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _quantityProblem = null);
  }

  Future<void> _submit() async {
    final controller = widget.controller;
    final quantity = _typed;
    final quantityProblem = controller.validateReturnQuantity(
      widget.issueId,
      quantity,
    );
    final reasonProblem = controller.validateReturnReason(_reason.text);
    setState(() {
      _quantityProblem = quantityProblem;
      _reasonProblem = reasonProblem;
    });
    if (quantityProblem != null || reasonProblem != null) return;

    final message = await controller.returnItems(
      widget.issueId,
      quantity: quantity,
      reason: _reason.text,
    );
    if (!mounted) return;
    // Closed only once recorded; otherwise it stays open as entered.
    if (message != null) Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return Obx(() {
      final busy =
          controller.submitting.value == AtkDeskDetailController.returnAction;
      final failure = controller.notice.value;
      final detail = controller.detail.value;
      final issue = detail?.issueById(widget.issueId);
      final unit = detail?.request.unit ?? '';
      final max = issue?.returnableQuantity ?? 0;
      final open = issue?.isReturnable ?? false;
      final typed = _typed;

      return AlertDialog(
        scrollable: true,
        title: const Text('Terima pengembalian barang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (issue != null) ...[
              Text(
                open
                    ? 'Penyerahan ${issue.number} • bisa dikembalikan '
                          '$max $unit'
                    : 'Penyerahan ${issue.number} • tidak ada lagi yang bisa '
                          'dikembalikan',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _quantity,
              enabled: !busy,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => _quantityProblem = null),
              decoration: appInputDecoration(
                theme,
                'Jumlah dikembalikan',
                helperText: 'Paling banyak $max $unit',
                prefixIcon: IconButton(
                  tooltip: 'Kurangi',
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: busy || typed == null || typed <= 1
                      ? null
                      : () => _step(-1, max),
                ),
                suffixIcon: IconButton(
                  tooltip: 'Tambah',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: busy || (typed != null && typed >= max)
                      ? null
                      : () => _step(1, max),
                ),
              ).copyWith(errorText: _quantityProblem, errorMaxLines: 3),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reason,
              enabled: !busy,
              minLines: 2,
              maxLines: 5,
              maxLength: AtkDeskDetailController.reasonMax,
              onChanged: (_) {
                if (_reasonProblem != null) {
                  setState(() => _reasonProblem = null);
                }
              },
              decoration: appInputDecoration(
                theme,
                'Alasan pengembalian',
                helperText: 'Wajib diisi, misalnya barang rusak atau berlebih.',
              ).copyWith(errorText: _reasonProblem),
            ),
            if (failure != null) ...[
              const SizedBox(height: 8),
              AppInlineNotice(
                tone: controller.noticeIsConflict.value
                    ? AppNoticeTone.warning
                    : AppNoticeTone.danger,
                message: failure,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          AppButton(
            label: 'Catat pengembalian',
            expand: false,
            busy: busy,
            onPressed: busy || !open ? null : _submit,
          ),
        ],
      );
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final AtkDeskDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = detail.request;
    final issued = atkIssuedLine(
      detail.issuedQuantity,
      request.quantity,
      request.unit,
    );
    final when = atkWhen(request.createdAt);
    final reason = detail.reason?.trim();
    final what = atkQuantityLine(
      request.itemName,
      request.quantity,
      request.unit,
    );

    return Semantics(
      container: true,
      label: [
        'Permintaan ATK ${request.number}',
        what,
        if (request.requesterName case final name?) 'dari $name',
        'status ${request.statusLabel}',
        ?issued,
        if (request.needsAction) 'perlu tindakan',
      ].join(', '),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(request.number, style: theme.textTheme.labelMedium),
                AppBadge(
                  label: request.statusLabel,
                  tone: atkStatusTone(request.status),
                ),
                if (request.needsAction)
                  const AppBadge(
                    label: 'Perlu tindakan',
                    tone: AppBadgeTone.warning,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(what, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (request.itemCode case final code?) AtkLine('Kode barang', code),
            if (request.requesterName case final name?)
              AtkLine('Pemohon', name),
            AtkLine('Lokasi pengambilan', request.locationName),
            if (issued != null) AtkLine('Penyerahan', issued),
            if (detail.returnedQuantity > 0)
              AtkLine(
                'Dikembalikan',
                '${detail.returnedQuantity} ${request.unit}',
              ),
            if (when != null) AtkLine('Diajukan', when),
            if (reason != null && reason.isNotEmpty) AtkLine('Alasan', reason),
          ],
        ),
      ),
    );
  }
}

class _Stock extends StatelessWidget {
  const _Stock({required this.detail});

  final AtkDeskDetail detail;

  @override
  Widget build(BuildContext context) {
    final stock = detail.stock;
    final unit = detail.request.unit;

    return Semantics(
      container: true,
      label:
          'Stok di lokasi ini: tersedia ${stock.available}, dipesan '
          '${stock.reserved}, stok ${stock.onHand} $unit',
      excludeSemantics: true,
      child: AtkSection(
        title: 'Stok di lokasi ini',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Figure(label: 'Tersedia', value: stock.available, unit: unit),
            _Figure(label: 'Dipesan', value: stock.reserved, unit: unit),
            _Figure(label: 'Stok', value: stock.onHand, unit: unit),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.unit});

  final String label;
  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text('$value $unit', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Handovers extends StatelessWidget {
  const _Handovers({
    required this.detail,
    required this.controller,
    required this.onReturn,
  });

  final AtkDeskDetail detail;
  final AtkDeskDetailController controller;
  final ValueChanged<AtkHandover> onReturn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = detail.request.unit;

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
                  Semantics(
                    container: true,
                    label: [
                      'Penyerahan ${issue.number}',
                      '${issue.quantity} $unit',
                      if (issue.issuedByName case final giver?) 'oleh $giver',
                      issue.isReceived
                          ? 'sudah diterima'
                          : 'belum dikonfirmasi penerima',
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
                            AppBadge(
                              label: issue.isReceived
                                  ? 'Diterima'
                                  : 'Belum dikonfirmasi',
                              tone: issue.isReceived
                                  ? AppBadgeTone.success
                                  : AppBadgeTone.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (issue.issuedByName case final giver?)
                          AtkLine('Diserahkan oleh', giver),
                        if (atkWhen(issue.issuedAt) case final at?)
                          AtkLine('Waktu penyerahan', at),
                        if (issue.receivedByName case final receiver?)
                          AtkLine('Diterima oleh', receiver),
                        if (atkWhen(issue.receivedAt) case final at?)
                          AtkLine('Waktu diterima', at),
                        if (issue.returnedQuantity > 0)
                          AtkLine(
                            'Dikembalikan',
                            '${issue.returnedQuantity} $unit',
                          ),
                        if (issue.isReturnable) ...[
                          const SizedBox(height: 8),
                          Obx(
                            () => AppButton(
                              label: 'Terima Pengembalian',
                              icon: Icons.assignment_return_outlined,
                              variant: AppButtonVariant.outlined,
                              onPressed: controller.submitting.value != null
                                  ? null
                                  : () => onReturn(issue),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Movements extends StatelessWidget {
  const _Movements({required this.detail});

  final AtkDeskDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = detail.request.unit;

    return AtkSection(
      title: 'Riwayat pergerakan stok',
      child: detail.movements.isEmpty
          ? Text('Belum ada pergerakan stok.', style: theme.textTheme.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final movement in detail.movements.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5, right: 8),
                          child: Icon(Icons.circle, size: 8),
                        ),
                        Expanded(
                          child: Text(
                            [
                              '${movement.label} ${movement.quantity} $unit',
                              ?atkWhen(movement.at),
                            ].join(' — '),
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
