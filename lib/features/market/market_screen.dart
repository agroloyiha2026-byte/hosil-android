import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../../models/market_models.dart';
import '../../models/stage5_models.dart';
import '../stage5_providers.dart';
import 'market_providers.dart';
import '../../core/widgets/region_dropdown.dart';
import '../ads/ad_banner.dart';
import 'product_card.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});
  @override
  ConsumerState<MarketScreen> createState() => _S();
}

class _S extends ConsumerState<MarketScreen> {
  final _scroll = ScrollController();
  String _catalog = 'products';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(productsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openFilters() {
    final lang = Localizations.localeOf(context).languageCode;
    var f = ref.read(filtersProvider);
    var regionSel = f.region;
    final min = TextEditingController(text: f.minPrice?.toString() ?? '');
    final max = TextEditingController(text: f.maxPrice?.toString() ?? '');
    final cats = ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.tr('filters'), style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: Text(ctx.tr('all')), selected: f.category == null, onSelected: (_) => set(() => f = f.copyWith(category: null))),
            for (final c in cats) ChoiceChip(label: Text(c.name(lang)), selected: f.category == c.slug, onSelected: (_) => set(() => f = f.copyWith(category: c.slug))),
          ]),
          const SizedBox(height: 12),
          RegionDropdown(label: ctx.tr('region'), allowAll: true, value: regionSel, onChanged: (v) => set(() => regionSel = v ?? '')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: AppTextField(controller: min, label: ctx.tr('price_from'), keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: AppTextField(controller: max, label: ctx.tr('price_to'), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 12),
          Text(ctx.tr('currency')),
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'UZS', label: Text('UZS')), ButtonSegment(value: 'USD', label: Text('USD'))],
              selected: {f.currency}, onSelectionChanged: (v) => set(() => f = f.copyWith(currency: v.first))),
          const SizedBox(height: 12),
          Text(ctx.tr('sort')),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'new', label: Text(ctx.tr('sort_new'))),
              ButtonSegment(value: 'price_asc', label: Text(ctx.tr('sort_price_asc'))),
              ButtonSegment(value: 'price_desc', label: Text(ctx.tr('sort_price_desc'))),
            ],
            selected: {f.sort}, onSelectionChanged: (v) => set(() => f = f.copyWith(sort: v.first)),
          ),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(ctx.tr('price_hint'), style: Theme.of(ctx).textTheme.bodySmall)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: AppButton(label: ctx.tr('reset'), outlined: true, onPressed: () {
              ref.read(filtersProvider.notifier).state = ProductFilters(query: ref.read(filtersProvider).query);
              Navigator.pop(ctx);
            })),
            const SizedBox(width: 8),
            Expanded(child: AppButton(label: ctx.tr('apply'), onPressed: () {
              ref.read(filtersProvider.notifier).state = f.copyWith(
                  region: regionSel, minPrice: double.tryParse(min.text.replaceAll(' ', '')), maxPrice: double.tryParse(max.text.replaceAll(' ', '')));
              Navigator.pop(ctx);
            })),
          ]),
        ])),
      )),
    );
  }

  Widget _warehouseCatalog(BuildContext context, AsyncValue<List<Warehouse>> state) => state.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(error: error, onRetry: () => ref.invalidate(warehousesProvider)),
        data: (warehouses) => warehouses.isEmpty
            ? EmptyView(message: context.tr('no_warehouses'), icon: Icons.warehouse_outlined)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: warehouses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final warehouse = warehouses[index];
                  return AppCard(
                    onTap: () => context.push('/warehouse/${warehouse.id}'),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ProductImage(warehouse.imageUrl),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(warehouse.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(warehouse.region, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 6),
                              Text(
                                '${context.tr('free_space')}: ${warehouse.freeTons} ${context.tr('tons')}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                warehouse.pricePerTonMonth == null
                                    ? context.tr('price_na')
                                    : '${warehouse.pricePerTonMonth} ${warehouse.currency} ${context.tr('price_month')}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  );
                },
              ),
      );

  void _selectCatalog(String value) {
    if (value == 'equipment' || value == 'logistics') {
      context.push('/services/$value');
      return;
    }
    setState(() => _catalog = value);
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(productsProvider);
    final f = ref.watch(filtersProvider);
    Widget body;
    if (_catalog == 'warehouses') {
      body = _warehouseCatalog(context, ref.watch(warehousesProvider));
    } else if (st.loading && st.items.isEmpty) {
      body = const LoadingView();
    } else if (st.error != null && st.items.isEmpty) {
      body = ErrorView(error: st.error!, onRetry: () => ref.read(productsProvider.notifier).refresh());
    } else if (st.items.isEmpty) {
      body = EmptyView(message: context.tr('no_products'));
    } else {
      body = GridView.builder(
        controller: _scroll, padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
        itemCount: st.items.length + (st.loading ? 1 : 0),
        itemBuilder: (_, i) => i >= st.items.length ? const Center(child: CircularProgressIndicator()) : ProductCard(st.items[i]),
      );
    }
    return SafeArea(
      top: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.local_pharmacy_outlined),
              label: Text(context.tr('agroapteka')),
              onPressed: () => context.push('/agroapteka'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(child: Text(context.tr('nav_market'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              if (_catalog == 'products')
                Badge(isLabelVisible: f.hasActive, child: IconButton.filledTonal(onPressed: _openFilters, icon: const Icon(Icons.tune))),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              for (final catalog in const ['products', 'warehouses', 'equipment', 'logistics'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(context.tr('catalog_$catalog')),
                    selected: _catalog == catalog,
                    onSelected: (_) => _selectCatalog(catalog),
                  ),
                ),
            ],
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: AdBanner(placement: 'market_top')),
        Expanded(child: RefreshIndicator(onRefresh: () => ref.read(productsProvider.notifier).refresh(), child: body)),
      ]),
    );
  }
}
