import 'package:flutter/material.dart';
import '../../app/localization/l10n.dart';
import '../regions.dart';

/// Tayyor hududlar ro'yxati (qo'lda yozish shart emas). allowAll: "Barchasi" varianti (filtrlar uchun).
class RegionDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowAll, required;
  const RegionDropdown({super.key, required this.label, required this.value, required this.onChanged, this.allowAll = false, this.required = false});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return DropdownButtonFormField<String>(
      value: (value != null && (regionsUz.contains(value) || (allowAll && value == ''))) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      items: [
        if (allowAll) DropdownMenuItem(value: '', child: Text(context.tr('all'))),
        for (final r in regionsUz) DropdownMenuItem(value: r, child: Text(regionLabel(r, lang))),
      ],
      onChanged: onChanged,
      validator: required ? (v) => (v == null || v.isEmpty) ? context.tr('v_required') : null : null,
    );
  }
}
