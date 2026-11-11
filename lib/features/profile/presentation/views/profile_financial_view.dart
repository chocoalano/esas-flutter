import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_section_header.dart';
import '../../data/models/cash_advance.dart';
import '../../data/models/employee_loan.dart';
import '../controllers/profile_financial_controller.dart';

class ProfileFinancialView extends GetView<ProfileFinancialController> {
  const ProfileFinancialView({super.key});

  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pinjaman & Kasbon'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (controller.error.value != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: palette.danger.foreground),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      controller.error.value!.message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: controller.loadFinancials,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadFinancials,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              children: [
                // ── Loans Section ──
                AppSectionHeader(
                  title: 'Pinjaman Karyawan',
                  subtitle: controller.outstandingTotal.value > 0
                      ? 'Total sisa: ${_currencyFormat.format(controller.outstandingTotal.value)}'
                      : 'Tidak ada pinjaman berjalan',
                  dense: true,
                  naturalCase: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.loans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Tidak ada catatan pinjaman aktif.',
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                    ),
                  )
                else
                  for (final loan in controller.loans) _LoanCard(loan: loan),

                const SizedBox(height: AppSpacing.xxl),

                // ── Advances Section ──
                AppSectionHeader(
                  title: 'Kasbon / Uang Muka',
                  subtitle: controller.unaccountedTotal.value > 0
                      ? 'Belum SPJ: ${_currencyFormat.format(controller.unaccountedTotal.value)}'
                      : 'Tidak ada kasbon berjalan',
                  dense: true,
                  naturalCase: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.advances.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Tidak ada catatan kasbon yang belum dipertanggungjawabkan.',
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                    ),
                  )
                else
                  for (final advance in controller.advances) _AdvanceCard(advance: advance),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan});

  final EmployeeLoan loan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loan.purpose.isNotEmpty ? loan.purpose : 'Pinjaman Karyawan',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.brandSubtle,
                    borderRadius: AppRadii.mdAll,
                  ),
                  child: Text(
                    loan.reference,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sisa Pinjaman:',
                  style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                ),
                Text(
                  ProfileFinancialView._currencyFormat.format(loan.outstanding),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.danger.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pokok Pinjaman:',
                  style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                ),
                Text(
                  ProfileFinancialView._currencyFormat.format(loan.principal),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sisa Angsuran:',
                  style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                ),
                Text(
                  '${loan.instalmentsLeft}x (${ProfileFinancialView._currencyFormat.format(loan.instalmentAmount)} / bln)',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({required this.advance});

  final CashAdvance advance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    advance.purpose.isNotEmpty ? advance.purpose : 'Kasbon Operasional',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.warning.background,
                    borderRadius: AppRadii.mdAll,
                    border: Border.all(color: palette.warning.border),
                  ),
                  child: Text(
                    advance.reference,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.warning.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nominal Kasbon:',
                  style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                ),
                Text(
                  ProfileFinancialView._currencyFormat.format(advance.amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (advance.disbursedAt != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tanggal Cair:',
                    style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                  ),
                  Text(
                    advance.disbursedAt!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

