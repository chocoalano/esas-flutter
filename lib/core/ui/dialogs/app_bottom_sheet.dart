import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Bottom sheet baku aplikasi.
///
/// Sebelumnya setiap sheet menyusun sendiri kotak berlatar `surface`, sudut
/// 16px, dan sebuah "grab handle" berupa `Container` 40×4 — tiga kali di satu
/// berkas saja, dengan warna gagang yang berbeda-beda. Bentuk dan gagangnya
/// kini datang dari `bottomSheetTheme`, dan fungsi ini hanya menambahkan judul,
/// jarak, serta ruang aman untuk papan ketik.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  String? description,
  bool isScrollControlled = true,
}) {
  final theme = Theme.of(context);
  final palette = theme.palette;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    // Sheet yang memuat input harus naik bersama papan ketik; tanpa ini kolom
    // catatan penolakan tertutup oleh keyboard di layar kecil.
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Baris kunci–nilai untuk panel rincian.
///
/// Label memakai lebar tetap sehingga nilainya sejajar di satu kolom. Nilai
/// yang tidak sejajar memaksa mata mencari ulang titik awal pada setiap baris.
class AppDetailRow extends StatelessWidget {
  const AppDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
    this.trailing,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                trailing ??
                Text(
                  value,
                  style:
                      valueStyle ??
                      theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                ),
          ),
        ],
      ),
    );
  }
}

/// Panel berisi beberapa [AppDetailRow], dipisahkan garis 1px.
class AppDetailPanel extends StatelessWidget {
  const AppDetailPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.xlAll,
        border: Border.all(color: palette.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.borderSubtle),
            children[i],
          ],
        ],
      ),
    );
  }
}
