import 'package:flutter/material.dart';
import '../../app/localization/l10n.dart';

String? dateKey(String? v) => (v == null || v.trim().isEmpty || DateTime.tryParse(v.trim()) != null) ? null : 'v_date';
String? httpsKey(String? v) => (v == null || v.trim().isEmpty || v.trim().startsWith('https://')) ? null : 'v_https';
String? intKey(String? v) => (v == null || v.trim().isEmpty || int.tryParse(v.trim()) != null) ? null : 'v_int';
String? slugKey(String? v) => RegExp(r'^[a-z0-9_]+$').hasMatch((v ?? '').trim()) ? null : 'v_slug';

/// 'YYYY-MM-DD' -> UTC ISO (kun oxiri uchun endOfDay). Bo'sh bo'lsa null.
String? isoOrNull(String v, {bool endOfDay = false}) {
  if (v.trim().isEmpty) return null;
  final d = DateTime.parse(v.trim());
  return (endOfDay ? DateTime(d.year, d.month, d.day, 23, 59, 59) : d).toUtc().toIso8601String();
}

class FieldSpec {
  final String key, label, initial;
  final List<String>? options;
  final Map<String, String>? optionLabels;
  final String? dependsOn;
  final Map<String, Map<String, String>>? dependentOptions;
  final bool required;
  final String? Function(String?)? validate;
  final TextInputType? keyboard;
  const FieldSpec(this.key, this.label, {this.initial = '', this.options, this.optionLabels,
    this.dependsOn, this.dependentOptions, this.required = false, this.validate, this.keyboard});
}

/// Oddiy forma oynasi: {kalit: qiymat} qaytaradi, bekor qilinsa null.
Future<Map<String, String>?> showFormDialog(BuildContext context, String title, List<FieldSpec> fields) {
  final ctrls = <String, TextEditingController>{};
  for (final field in fields) {
    var value = field.initial;
    if (field.options != null && !field.options!.contains(value)) value = field.options!.first;
    if (field.dependentOptions != null) {
      final parentValue = ctrls[field.dependsOn]?.text;
      final available = parentValue == null ? null : field.dependentOptions![parentValue];
      if (parentValue == null || (available != null && !available.containsKey(value))) {
        value = '';
      }
    }
    ctrls[field.key] = TextEditingController(text: value);
  }
  final form = GlobalKey<FormState>();
  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final f in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: f.options != null || f.dependentOptions?.containsKey(ctrls[f.dependsOn]?.text) == true
                    ? Builder(builder: (context) {
                        final dynamicOptions = f.dependentOptions?[ctrls[f.dependsOn]?.text];
                        final keys = f.options ?? dynamicOptions?.keys.toList() ?? const <String>[];
                        final value = keys.contains(ctrls[f.key]!.text) ? ctrls[f.key]!.text : null;
                        return DropdownButtonFormField<String>(
                          value: value,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: f.label),
                          hint: Text(ctx.tr(keys.isEmpty ? 'banner_target_empty' : 'banner_target_select')),
                          items: [
                            for (final option in keys)
                              DropdownMenuItem(
                                value: option,
                                child: Text(f.optionLabels?[option] ?? dynamicOptions?[option] ?? option),
                              ),
                          ],
                          validator: (selected) {
                            if (f.required && (selected == null || selected.isEmpty)) return ctx.tr('v_required');
                            final key = f.validate?.call(selected);
                            return key == null ? null : ctx.tr(key);
                          },
                          onChanged: (next) {
                            ctrls[f.key]!.text = next ?? '';
                            for (final dependent in fields.where((field) => field.dependsOn == f.key)) {
                              final available = dependent.dependentOptions?[next];
                              if (available == null || !available.containsKey(ctrls[dependent.key]!.text)) {
                                ctrls[dependent.key]!.clear();
                              }
                            }
                            setDialogState(() {});
                          },
                        );
                      })
                    : TextFormField(
                        controller: ctrls[f.key], keyboardType: f.keyboard, decoration: InputDecoration(labelText: f.label),
                        validator: (v) {
                          if (f.required && (v == null || v.trim().isEmpty)) return ctx.tr('v_required');
                          final k = f.validate?.call(v);
                          return k == null ? null : ctx.tr(k);
                        }),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('cancel'))),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(ctx, {for (final e in ctrls.entries) e.key: e.value.text.trim()});
          },
          child: Text(ctx.tr('save')),
        ),
      ],
    )),
  ).whenComplete(() {
    for (final controller in ctrls.values) {
      controller.dispose();
    }
  });
}

Future<bool> confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('delete'))),
        ],
      ),
    ) ??
    false;
