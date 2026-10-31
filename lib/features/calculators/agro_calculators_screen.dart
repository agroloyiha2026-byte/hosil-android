import 'package:flutter/material.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import 'agro_calculations.dart';

class AgroCalculatorsScreen extends StatefulWidget {
  const AgroCalculatorsScreen({super.key});

  @override
  State<AgroCalculatorsScreen> createState() => _AgroCalculatorsScreenState();
}

class _AgroCalculatorsScreenState extends State<AgroCalculatorsScreen> {
  static const _types = ['seed', 'fertilizer', 'npk', 'irrigation', 'harvest', 'cost'];
  final _first = TextEditingController();
  final _second = TextEditingController();
  final _third = TextEditingController();
  final _fourth = TextEditingController();
  String _type = 'seed';
  String? _result;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _third.dispose();
    _fourth.dispose();
    super.dispose();
  }

  double _parse(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim().replaceAll(' ', '').replaceAll(',', '.'));
    if (value == null || !value.isFinite) throw const FormatException();
    return value;
  }

  void _calculate() {
    try {
      final a = _parse(_first);
      final b = _parse(_second);
      final value = switch (_type) {
        'seed' => '${AgroCalculations.seedQuantityKg(rateKgPerHa: a, areaHa: b).toStringAsFixed(2)} kg',
        'fertilizer' => '${AgroCalculations.fertilizerQuantityKg(rateKgPerHa: a, areaHa: b).toStringAsFixed(2)} kg',
        'npk' => _calculateNpk(a, b),
        'irrigation' => '${AgroCalculations.irrigationVolumeM3(waterDepthMm: a, areaHa: b).toStringAsFixed(2)} m³',
        'harvest' => '${AgroCalculations.expectedHarvestTons(yieldTonsPerHa: a, areaHa: b).toStringAsFixed(2)} t',
        'cost' => AgroCalculations.totalCost(quantity: a, unitCost: b).toStringAsFixed(2),
        _ => throw StateError('Unknown calculator'),
      };
      setState(() { _result = value; _error = null; });
    } on FormatException {
      setState(() { _result = null; _error = context.tr('calculator_invalid_number'); });
    } on ArgumentError {
      setState(() { _result = null; _error = context.tr('calculator_invalid_range'); });
    }
  }

  String _calculateNpk(double productKg, double nitrogenPercent) {
    final content = AgroCalculations.npkContent(
      productKg: productKg,
      nitrogenPercent: nitrogenPercent,
      phosphorusPercent: _parse(_third),
      potassiumPercent: _parse(_fourth),
    );
    return 'N: ${content.nitrogenKg.toStringAsFixed(2)} kg · '
        'P: ${content.phosphorusKg.toStringAsFixed(2)} kg · '
        'K: ${content.potassiumKg.toStringAsFixed(2)} kg';
  }

  @override
  Widget build(BuildContext context) {
    final firstKey = 'calc_${_type}_first';
    final secondKey = 'calc_${_type}_second';
    final thirdKey = 'calc_${_type}_third';
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('service_calculators'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(labelText: context.tr('calculator_type')),
            items: [for (final type in _types) DropdownMenuItem(value: type, child: Text(context.tr('calc_type_$type')))],
            onChanged: (value) => setState(() { _type = value ?? 'seed'; _result = null; _error = null; }),
          ),
          const SizedBox(height: 16),
          AppTextField(controller: _first, label: context.tr(firstKey), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 12),
          AppTextField(controller: _second, label: context.tr(secondKey), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          if (_type == 'npk') ...[
            const SizedBox(height: 12),
            AppTextField(controller: _third, label: context.tr(thirdKey), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            AppTextField(controller: _fourth, label: context.tr('calc_npk_fourth'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
          const SizedBox(height: 12),
          Text(context.tr('calculator_formula_$_type'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          AppButton(label: context.tr('calculate'), icon: Icons.calculate_outlined, onPressed: _calculate),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorText(_error),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('calculator_result'), style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  SelectableText(_result!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(context.tr('calculator_estimate_note'), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
