import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/header_band.dart';
import '../../core/widgets/widgets.dart';
import '../../models/market_models.dart';
import '../../models/stage5_models.dart';
import '../ads/ad_banner.dart';
import '../market/market_providers.dart';
import '../market/product_card.dart';
import '../notifications/notification_bridge.dart';
import '../profile/profile_button.dart';
import '../stage5_providers.dart';
import 'site_settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _S();
}

class _S extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _banner(BannerItem b) {
    final v = b.linkValue;
    if (v == null) return;
    if (b.linkType == 'product') {
      context.push('/product/$v');
    } else if (b.linkType == 'category') {
      ref.read(filtersProvider.notifier).state = ProductFilters(category: v);
      context.go('/market');
    } else if (b.linkType == 'url' && v.startsWith('https://')) {
      launchUrl(Uri.parse(v), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final s = ref.watch(siteSettingsProvider).valueOrNull ?? const <String, String>{};
    final notes = [s['maintenance_notice'], s['announcement']].where((e) => (e ?? '').isNotEmpty).toList();
    return Column(children: [
      HeaderBand(
        child: Column(children: [
          Row(children: [
            const Text('🌾 Hosil X', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const Spacer(),
            Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: IconButton(color: Colors.white, icon: const Icon(Icons.notifications_none), onPressed: () => context.push('/notifications')),
            ),
            const SizedBox(width: 8),
            const ProfileButton(),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) {
              ref.read(filtersProvider.notifier).state = ProductFilters(query: v);
              context.go('/market');
            },
            decoration: InputDecoration(
              hintText: context.tr('search_hint'), prefixIcon: const Icon(Icons.search), filled: true,
              fillColor: Theme.of(context).colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bannersProvider);
            ref.invalidate(categoriesProvider);
            ref.invalidate(recentProductsProvider);
            ref.invalidate(warehousesProvider);
            ref.invalidate(unreadCountProvider);
            ref.invalidate(adsProvider);
          },
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (notes.isNotEmpty)
              AppCard(child: Row(children: [const Icon(Icons.campaign_outlined), const SizedBox(width: 10), Expanded(child: Text(notes.join('\n')))])),
            const AdBanner(placement: 'home_top'),
            ref.watch(bannersProvider).when(
                  loading: () => const SizedBox(height: 140, child: LoadingView()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => list.isEmpty ? const SizedBox.shrink() : _Banners(list, _banner),
                ),
            const SizedBox(height: 16),
            Text(context.tr('categories'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ref.watch(categoriesProvider).when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (cats) => ListView(scrollDirection: Axis.horizontal, children: [
                      for (final c in cats)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text('${c.icon ?? ''} ${c.name(lang)}'.trim()),
                            onPressed: () {
                              ref.read(filtersProvider.notifier).state = ProductFilters(category: c.slug);
                              context.go('/market');
                            },
                          ),
                        ),
                    ]),
                  ),
            ),
            const SizedBox(height: 20),
            Text(context.tr('recent'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 230,
              child: AsyncValueView<List<Product>>(
                value: ref.watch(recentProductsProvider),
                onRetry: () => ref.invalidate(recentProductsProvider),
                isEmpty: (l) => l.isEmpty,
                data: (l) => ListView(scrollDirection: Axis.horizontal, children: [
                  for (final p in l) SizedBox(width: 170, child: Padding(padding: const EdgeInsets.only(right: 12), child: ProductCard(p))),
                ]),
              ),
            ),
            const AdBanner(placement: 'home_middle'),
            const SizedBox(height: 12),
            Row(children: [
              Text(context.tr('home_warehouses'), style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(onPressed: () => context.push('/warehouses'), child: Text(context.tr('see_all'))),
            ]),
            SizedBox(
              height: 150,
              child: AsyncValueView<List<Warehouse>>(
                value: ref.watch(warehousesProvider),
                onRetry: () => ref.invalidate(warehousesProvider),
                isEmpty: (l) => l.isEmpty,
                data: (l) => ListView(scrollDirection: Axis.horizontal, children: [
                  for (final w in l.take(8))
                    SizedBox(
                      width: 220,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: AppCard(
                          onTap: () => context.push('/warehouse/${w.id}'),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('🏭 ${w.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('📍 ${w.region}', style: Theme.of(context).textTheme.bodySmall),
                            const Spacer(),
                            Text('${context.tr('free_space')}: ${w.freeTons.toStringAsFixed(0)} ${context.tr('tons')}'),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _Banners extends StatefulWidget {
  final List<BannerItem> list;
  final void Function(BannerItem) onTap;
  const _Banners(this.list, this.onTap);
  @override
  State<_Banners> createState() => _BannersState();
}

class _BannersState extends State<_Banners> {
  int _i = 0;
  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: 150,
          child: PageView(
            onPageChanged: (v) => setState(() => _i = v),
            children: [
              for (final b in widget.list)
                GestureDetector(
                  onTap: () => widget.onTap(b),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(fit: StackFit.expand, children: [
                      ProductImage(b.imageUrl),
                      Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Color(0xCC000000), Colors.transparent]))),
                      Positioned(left: 14, right: 14, bottom: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(b.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                        if (b.subtitle != null) Text(b.subtitle!, style: const TextStyle(color: Colors.white70)),
                      ])),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        if (widget.list.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < widget.list.length; k++)
                Container(margin: const EdgeInsets.all(3), width: k == _i ? 18 : 7, height: 7,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: Theme.of(context).colorScheme.primary.withOpacity(k == _i ? 1 : 0.25))),
            ]),
          ),
      ]);
}
