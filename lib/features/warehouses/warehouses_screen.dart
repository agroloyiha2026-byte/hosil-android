import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/widgets/widgets.dart';
import '../../models/stage5_models.dart';
import '../auth/auth_widgets.dart';
import '../market/product_card.dart';
import '../stage5_providers.dart';
import 'warehouse_repository.dart' show WarehouseFilters;

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  Future<void> _showFilters(BuildContext context, WidgetRef ref) async {
    final filters = ref.read(warehouseFiltersProvider);
    final region = TextEditingController(text: filters.region ?? '');
    final product = TextEditingController(text: filters.acceptedProduct ?? '');
    final capacity = TextEditingController(text: filters.minCapacityTons?.toString() ?? '');
    final free = TextEditingController(text: filters.minFreeTons?.toString() ?? '');
    final price = TextEditingController(text: filters.maxPricePerTonMonth?.toString() ?? '');
    var storageType = filters.storageType;
    String? error;
    double? parse(TextEditingController controller) {
      if (controller.text.trim().isEmpty) return null;
      final value = double.tryParse(controller.text.trim().replaceAll(' ', '').replaceAll(',', '.'));
      return value != null && value.isFinite && value >= 0 ? value : double.nan;
    }

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(sheetContext.tr('filters'), style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(controller: region, decoration: InputDecoration(labelText: sheetContext.tr('region'))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: storageType,
                  decoration: InputDecoration(labelText: sheetContext.tr('storage_type')),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(sheetContext.tr('all'))),
                    for (final type in const ['cold', 'dry', 'vegetable', 'grain', 'other'])
                      DropdownMenuItem<String?>(value: type, child: Text(sheetContext.tr('st_$type'))),
                  ],
                  onChanged: (value) => setSheetState(() => storageType = value),
                ),
                const SizedBox(height: 10),
                TextField(controller: product, decoration: InputDecoration(labelText: sheetContext.tr('product_type'))),
                const SizedBox(height: 10),
                TextField(controller: capacity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: sheetContext.tr('capacity'))),
                const SizedBox(height: 10),
                TextField(controller: free, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: sheetContext.tr('free_space'))),
                const SizedBox(height: 10),
                TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: sheetContext.tr('warehouse_price_optional'))),
                if (error != null) ErrorText(error),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextButton(onPressed: () {
                    ref.read(warehouseFiltersProvider.notifier).state = const WarehouseFilters();
                    ref.invalidate(warehousesProvider);
                    Navigator.pop(sheetContext);
                  }, child: Text(sheetContext.tr('reset')))),
                  Expanded(child: FilledButton(onPressed: () {
                    final parsedCapacity = parse(capacity);
                    final parsedFree = parse(free);
                    final parsedPrice = parse(price);
                    if ([parsedCapacity, parsedFree, parsedPrice].any((value) => value?.isNaN ?? false)) {
                      setSheetState(() => error = sheetContext.tr('warehouse_invalid_number'));
                      return;
                    }
                    ref.read(warehouseFiltersProvider.notifier).state = WarehouseFilters(
                      region: region.text.trim().isEmpty ? null : region.text.trim(),
                      storageType: storageType,
                      acceptedProduct: product.text.trim().isEmpty ? null : product.text.trim(),
                      minCapacityTons: parsedCapacity,
                      minFreeTons: parsedFree,
                      maxPricePerTonMonth: parsedPrice,
                    );
                    ref.invalidate(warehousesProvider);
                    Navigator.pop(sheetContext);
                  }, child: Text(sheetContext.tr('apply')))),
                ]),
              ]),
            ),
          ),
        ),
      );
    } finally {
      region.dispose();
      product.dispose();
      capacity.dispose();
      free.dispose();
      price.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(context.tr('warehouses')), actions: [
          IconButton(
            tooltip: context.tr('filters'),
            onPressed: () => _showFilters(context, ref),
            icon: Badge(isLabelVisible: ref.watch(warehouseFiltersProvider).hasActive, child: const Icon(Icons.tune)),
          ),
        ]),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => ref.read(warehouseQueryProvider.notifier).state = v,
              decoration: InputDecoration(hintText: context.tr('wh_search'), prefixIcon: const Icon(Icons.search), filled: true,
                  fillColor: Theme.of(context).colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Warehouse>>(
              value: ref.watch(warehousesProvider),
              onRetry: () => ref.invalidate(warehousesProvider),
              isEmpty: (l) => l.isEmpty,
              data: (l) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(warehousesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16), itemCount: l.length, separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _WarehouseCard(l[i]),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _WarehouseCard extends StatelessWidget {
  final Warehouse w;
  const _WarehouseCard(this.w);

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final ratio = w.capacityTons <= 0 ? 0.0 : (w.freeTons / w.capacityTons).clamp(0.0, 1.0);
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/warehouse/${w.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(aspectRatio: 16 / 7, child: ProductImage(w.imageUrl)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text('📍 ${w.region} · ${context.tr('st_${w.storageType}')}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: ratio, minHeight: 8, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 6),
            Text('${context.tr('free_space')}: ${fmtNum(w.freeTons)} / ${fmtNum(w.capacityTons)} ${context.tr('tons')}'),
            const SizedBox(height: 4),
            Text(w.pricePerTonMonth == null ? context.tr('price_na') : '${fmtNum(w.pricePerTonMonth!)} ${w.currency} ${context.tr('price_month')}',
                style: TextStyle(color: s.primary, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }
}
