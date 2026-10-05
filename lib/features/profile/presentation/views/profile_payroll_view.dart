import 'dart:io';

import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/models/payslip.dart';
import '../controllers/profile_tab_controllers.dart';

final _money = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

class ProfilePayrollView extends StatefulWidget {
  const ProfilePayrollView({super.key});

  @override
  State<ProfilePayrollView> createState() => _ProfilePayrollViewState();
}

class _ProfilePayrollViewState extends State<ProfilePayrollView> {
  final controller = Get.find<ProfilePayrollController>();

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    final id = arguments is Map
        ? int.tryParse('${arguments['slip_id']}')
        : null;
    if (id != null && id > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSlip(context, id);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Slip Gaji')),
    body: Obx(() {
      if (controller.isLoading.value && controller.slips.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.errorMessage.value != null && controller.slips.isEmpty) {
        return AppErrorState(
          message: controller.errorMessage.value!,
          onRetry: controller.refreshSlips,
        );
      }
      return RefreshIndicator(
        onRefresh: controller.refreshSlips,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (controller.errorMessage.value != null)
              AppErrorState(
                message: controller.errorMessage.value!,
                onRetry: controller.refreshSlips,
              ),
            if (controller.slips.isEmpty)
              const AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada slip gaji',
                message: 'Slip akan tersedia setelah payroll disetujui.',
              ),
            for (final slip in controller.slips)
              Card(
                child: ListTile(
                  title: Text(slip.code),
                  subtitle: Text(
                    '${slip.runLabel} · ${slip.period['start_date']} – ${slip.period['end_date']}\n${slip.statusLabel}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSlip(context, slip.id),
                ),
              ),
            if (controller.hasMore.value)
              TextButton(
                onPressed: controller.isMoreLoading.value
                    ? null
                    : controller.loadMore,
                child: Text(
                  controller.isMoreLoading.value
                      ? 'Memuat…'
                      : 'Muat periode sebelumnya',
                ),
              ),
          ],
        ),
      );
    }),
  );

  Future<void> _openSlip(BuildContext context, int id) async {
    controller.loadDetail(id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Obx(() {
          if (controller.isDetailLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.detailError.value != null) {
            return AppErrorState(
              message: controller.detailError.value!,
              onRetry: () => controller.loadDetail(id),
            );
          }
          final slip = controller.detail.value;
          if (slip == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(slip.code, style: Theme.of(context).textTheme.headlineSmall),
              Text('${slip.employee['name'] ?? ''} · ${slip.statusLabel}'),
              Text(slip.runLabel),
              Text('${slip.period['start_date']} – ${slip.period['end_date']}'),
              const SizedBox(height: 20),
              Text(
                'Gaji bersih',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                _money.format(slip.takeHomePay),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Divider(height: 32),
              Text(
                'Pendapatan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ..._lines(slip.earnings),
              _amount('Total pendapatan', slip.grossIncome),
              const Divider(height: 32),
              Text('Potongan', style: Theme.of(context).textTheme.titleMedium),
              ..._lines(slip.deductions),
              _amount('Total potongan', slip.totalDeduction),
              const Divider(height: 32),
              Text(
                'Rekening penerima',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${slip.bank['name'] ?? '—'} · ${slip.bank['number'] ?? '—'}',
              ),
              Text('${slip.bank['holder'] ?? ''}'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: controller.isDownloading.value
                    ? null
                    : () => _download(context, slip.id),
                icon: const Icon(Icons.download),
                label: Text(
                  controller.isDownloading.value ? 'Mengunduh…' : 'Unduh PDF',
                ),
              ),
            ],
          );
        }),
      ),
    );
    controller.closeDetail();
  }

  Iterable<Widget> _lines(List<PayslipLine> lines) => lines
      .where((line) => line.amount != 0)
      .map((line) => _amount(line.label, line.amount));

  Widget _amount(String label, double amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(_money.format(amount)),
      ],
    ),
  );

  Future<void> _download(BuildContext context, int id) async {
    controller.isDownloading.value = true;
    try {
      final pdf = await controller.download(id);
      if (!context.mounted) return;
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan slip gaji',
        fileName: pdf.filename,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdf.bytes,
      );
      if (path != null && !Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(pdf.bytes, flush: true);
      }
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Slip gaji tersimpan.')));
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slip gaji gagal diunduh. Silakan coba lagi.'),
          ),
        );
      }
    } finally {
      controller.isDownloading.value = false;
    }
  }
}
