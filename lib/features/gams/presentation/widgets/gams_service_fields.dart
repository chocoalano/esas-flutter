import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../../data/models/gams_service_request.dart';
import '../controllers/gams_create_controller.dart';

/// The chosen GA service's own request fields (FUNC-A01).
///
/// What a service asks for comes from the server; this only draws it. A
/// service with no extra field draws nothing.
class GamsServiceFields extends StatelessWidget {
  const GamsServiceFields({super.key, required this.controller});

  final GamsCreateController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final definition = controller.selectedDefinition;
      if (definition == null || definition.fields.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in definition.fields) ...[
            const SizedBox(height: AppSpacing.sm),
            _FieldInput(
              // A new service is a new form: nothing typed for the previous
              // one carries over.
              key: ValueKey('${definition.id}:${field.key}'),
              field: field,
              controller: controller,
            ),
          ],
        ],
      );
    });
  }
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({super.key, required this.field, required this.controller});

  final GamsRequestField field;
  final GamsCreateController controller;

  String get _label =>
      field.required ? field.label : '${field.label} (opsional)';

  Object? get _value => controller.fieldValues[field.key];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (field.type) {
      case GamsFieldType.text:
      case GamsFieldType.textarea:
      case GamsFieldType.number:
      case GamsFieldType.unknown:
        final number = field.type == GamsFieldType.number;
        final long = field.type == GamsFieldType.textarea;
        return TextFormField(
          initialValue: _value?.toString(),
          minLines: long ? 3 : 1,
          maxLines: long ? 5 : 1,
          maxLength: number ? null : (long ? 2000 : 150),
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : (long ? TextInputType.multiline : TextInputType.text),
          decoration: appInputDecoration(theme, _label),
          onChanged: (raw) => controller.setField(
            field.key,
            number ? num.tryParse(raw.trim().replaceAll(',', '.')) : raw.trim(),
          ),
        );
      case GamsFieldType.boolean:
        return Obx(
          () => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_label),
            value: controller.fieldValues[field.key] == true,
            onChanged: (on) => controller.setField(field.key, on),
          ),
        );
      case GamsFieldType.select:
        return DropdownButtonFormField<String>(
          initialValue: _value is String ? _value! as String : null,
          isExpanded: true,
          decoration: appInputDecoration(theme, _label),
          items: [
            for (final option in field.options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (option) => controller.setField(field.key, option),
        );
      case GamsFieldType.multiSelect:
        return Obx(() {
          final chosen = <String>[
            ...(controller.fieldValues[field.key] as List?)?.cast<String>() ??
                const [],
          ];
          return InputDecorator(
            decoration: appInputDecoration(theme, _label),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in field.options)
                  FilterChip(
                    label: Text(option),
                    selected: chosen.contains(option),
                    onSelected: (on) {
                      final next = [...chosen]..remove(option);
                      if (on) next.add(option);
                      controller.setField(field.key, next);
                    },
                  ),
              ],
            ),
          );
        });
      case GamsFieldType.date:
      case GamsFieldType.datetime:
        return Obx(() {
          final value = controller.fieldValues[field.key];
          final withTime = field.type == GamsFieldType.datetime;
          final shown = value is DateTime
              ? DateFormat(
                  withTime ? 'd MMM yyyy, HH:mm' : 'd MMM yyyy',
                  'id_ID',
                ).format(value)
              : '';
          return TextField(
            readOnly: true,
            controller: TextEditingController(text: shown),
            decoration: appInputDecoration(
              theme,
              _label,
            ).copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined)),
            onTap: () => _pick(context, withTime),
          );
        });
    }
  }

  Future<void> _pick(BuildContext context, bool withTime) async {
    final now = DateTime.now();
    final current = _value is DateTime ? _value! as DateTime : now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null) return;

    if (!withTime) {
      controller.setField(field.key, date);
      return;
    }

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;

    controller.setField(
      field.key,
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}
