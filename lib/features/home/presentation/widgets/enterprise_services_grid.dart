import 'package:flutter/material.dart';

import '../../../../core/registry/module_registry.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/layout/app_breakpoints.dart';

class EnterpriseServicesGrid extends StatelessWidget {
  const EnterpriseServicesGrid({
    super.key,
    required this.services,
    required this.onTapService,
  });

  final List<EnterpriseServiceItem> services;
  final void Function(EnterpriseServiceItem service) onTapService;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();

    final int columns = AppLayout.of(context).quickActionColumns.clamp(1, 6);
    final List<Widget> rows = <Widget>[];

    for (int start = 0; start < services.length; start += columns) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: AppSpacing.md));
      }

      final List<Widget> cells = <Widget>[];

      for (int column = 0; column < columns; column++) {
        if (column > 0) {
          cells.add(const SizedBox(width: AppSpacing.sm));
        }

        final int index = start + column;

        cells.add(
          Expanded(
            child: index < services.length
                ? _EnterpriseServiceTile(
                    service: services[index],
                    onTap: () => onTapService(services[index]),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cells,
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _EnterpriseServiceTile extends StatefulWidget {
  const _EnterpriseServiceTile({
    required this.service,
    required this.onTap,
  });

  final EnterpriseServiceItem service;
  final VoidCallback onTap;

  @override
  State<_EnterpriseServiceTile> createState() => _EnterpriseServiceTileState();
}

class _EnterpriseServiceTileState extends State<_EnterpriseServiceTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final item = widget.service;

    final Color background = theme.colorScheme.surface;
    final Color foreground = theme.colorScheme.onSurface;
    final Color edge = palette.borderSubtle;

    return Semantics(
      button: true,
      label: item.title,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppRadii.xlAll,
          onHighlightChanged: (val) {
            if (_pressed != val) {
              setState(() => _pressed = val);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedScale(
                  scale: _pressed ? 0.94 : 1,
                  duration: AppDurations.fast,
                  curve: AppMotion.standard,
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: AppRadii.xlAll,
                      border: Border.all(color: edge),
                    ),
                    child: Icon(
                      item.icon,
                      size: AppIconSizes.xxl,
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.tight),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

