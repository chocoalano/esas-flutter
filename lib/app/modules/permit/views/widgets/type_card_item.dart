import 'package:esas/app/data/Permit/leave_type.m.dart';
import 'package:flutter/material.dart';

class TypeCardItem extends StatelessWidget {
  final LeaveType item;
  final IconData icon;
  final ThemeData theme;
  final VoidCallback onTap;

  const TypeCardItem({
    super.key,
    required this.item,
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Gunakan ukuran proporsional untuk radius dan font
    final avatarRadius = screenWidth * 0.10; // sekitar 38px untuk 380px screen
    final iconSize = screenWidth * 0.09; // sekitar 34px
    final paddingSize = screenWidth * 0.03; // sekitar 12px
    final spacing = screenWidth * 0.04; // sekitar 16px
    final fontSize = screenWidth * 0.038; // sekitar 14-15px

    return Card(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      shadowColor: theme.shadowColor.withAlpha(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(paddingSize),
          child: Column(
            children: [
              SizedBox(height: spacing),
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: theme.colorScheme.primary.withAlpha(20),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: spacing),
              Text(
                item.type,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              _buildPaymentStatusIndicator(item.isPayed, theme, fontSize),
              SizedBox(height: spacing * 0.75),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentStatusIndicator(
    bool isPayed,
    ThemeData theme,
    double fontSize,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isPayed ? Icons.paid : Icons.money_off,
          size: fontSize,
          color: isPayed ? Colors.green[700] : theme.colorScheme.error,
        ),
        const SizedBox(width: 6),
        Text(
          isPayed ? 'Tetap Bayar' : 'Tidak Bayar',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: fontSize * 0.9,
            color: isPayed ? Colors.green[700] : theme.colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
