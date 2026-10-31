import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/localization/l10n.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../models/market_models.dart';
import '../../models/stage5_models.dart';
import '../auth/session_controller.dart';
import '../ads/ad_banner.dart';
import '../market/market_providers.dart';
import '../market/product_card.dart';
import '../notifications/notification_bridge.dart';
import '../stage5_providers.dart';
import '../services/service_providers.dart';
import '../agroapteka/agroapteka_repository.dart';
import 'site_settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _S();
}

class _S extends ConsumerState<HomeScreen> {
  bool _showAllServices = false;

  static const _services = <_HomeService>[
    _HomeService('service_doctor', Icons.medical_services_outlined, route: '/assistant?mode=doctor'),
    _HomeService('service_weather', Icons.wb_sunny_outlined, route: '/weather'),
    _HomeService('service_calculators', Icons.calculate_outlined, route: '/calculators'),
    _HomeService('service_warehouses', Icons.warehouse_outlined, route: '/warehouses'),
    _HomeService('service_logistics', Icons.local_shipping_outlined, route: '/services/logistics'),
    _HomeService('service_equipment', Icons.agriculture_outlined, route: '/services/equipment'),
    _HomeService('service_passport', Icons.qr_code_2_outlined, route: '/passports'),
    _HomeService('service_fieldbook', Icons.menu_book_outlined, route: '/fieldbook'),
    _HomeService('service_finance', Icons.account_balance_wallet_outlined, route: '/finance'),
    _HomeService('service_price_analysis', Icons.insights_outlined, route: '/assistant?mode=price'),
  ];

  Future<void> _banner(BannerItem b) async {
    final v = b.linkValue;
    if (v == null || v.trim().isEmpty || b.linkType == 'none') {
      await _showBannerDetails(b);
      return;
    }
    try {
      switch (b.linkType) {
      case 'product':
        final product = await ref.read(marketRepositoryProvider).product(v);
        if (!mounted) return;
        if (product == null) {
          await _showBannerDetails(b);
          return;
        }
        context.push('/product/${Uri.encodeComponent(v)}');
        return;
      case 'category':
        final categories = await ref.read(categoriesProvider.future);
        if (!mounted) return;
        if (!categories.any((category) => category.slug == v)) {
          await _showBannerDetails(b);
          return;
        }
        ref.read(filtersProvider.notifier).state = ProductFilters(category: v);
        context.go('/market');
        return;
      case 'agroapteka':
        final store = await AgroaptekaRepository().publicStore(v);
        if (!mounted) return;
        if (store == null) {
          await _showBannerDetails(b);
          return;
        }
        context.push('/agroapteka/store/${Uri.encodeComponent(v)}');
        return;
      case 'warehouse':
        final warehouse = await ref.read(warehouseRepoProvider).get(v);
        if (!mounted) return;
        if (warehouse == null) {
          await _showBannerDetails(b);
          return;
        }
        context.push('/warehouse/${Uri.encodeComponent(v)}');
        return;
      case 'equipment':
      case 'logistics':
        final listing = await ref.read(serviceRepoProvider).getPublic(b.linkType, v);
        if (!mounted) return;
        if (listing == null) {
          await _showBannerDetails(b);
          return;
        }
        context.push('/service/${b.linkType}/${Uri.encodeComponent(v)}');
        return;
      case 'url':
        final uri = Uri.tryParse(v);
        if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty) {
          try {
            final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (!opened && mounted) _showBannerError();
          } catch (_) {
            if (mounted) _showBannerError();
          }
          return;
        }
        break;
      }
      await _showBannerDetails(b);
    } catch (_) {
      if (mounted) _showBannerError();
    }
  }

  void _showBannerError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('error_generic'))),
    );
  }

  Future<void> _showBannerDetails(BannerItem banner) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      content: SizedBox(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 16 / 9, child: ProductImage(banner.imageUrl)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                child: Text(banner.title, style: Theme.of(dialogContext).textTheme.titleLarge),
              ),
              if ((banner.subtitle ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: Text(banner.subtitle!),
                ),
            ],
          )),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('close'))),
      ],
    ),
  );

  void _openService(BuildContext context, _HomeService service) {
    if (service.route != null) {
      context.push(service.route!);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(service.icon, size: 38, color: Theme.of(sheetContext).colorScheme.primary),
            const SizedBox(height: 12),
            Text(sheetContext.tr(service.titleKey), style: Theme.of(sheetContext).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(sheetContext.tr('service_not_connected'), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final canCreateListing = ref.watch(
      sessionProvider.select((state) => state.profile?.role == 'farmer' || state.profile?.role == 'admin'),
    );
    final s = ref.watch(siteSettingsProvider).valueOrNull ?? const <String, String>{};
    final bannerState = ref.watch(bannersProvider);
    final categoryState = ref.watch(categoriesProvider);
    final notes = [s['maintenance_notice'], s['announcement']].where((e) => (e ?? '').isNotEmpty).toList();
    return Column(children: [
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
            bannerState.when(
              loading: () => const SizedBox(height: 140, child: LoadingView()),
              error: (_, __) => _InlineLoadError(
                message: context.tr('banner_load_error'),
                onRetry: () => ref.invalidate(bannersProvider),
              ),
              data: (list) => list.isEmpty ? _BannerFallback(onTap: () => context.go('/market')) : _Banners(list, _banner),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text(context.tr('quick_services'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                TextButton(
                  onPressed: () => setState(() => _showAllServices = !_showAllServices),
                  child: Text(context.tr(_showAllServices ? 'services_less' : 'services_all')),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 600 ? 3 : 4;
                final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final items = _showAllServices ? _services : _services.take(8).toList();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: ((columns == 3 ? 96 : 104) * textScale).clamp(96, 148).toDouble(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final service = items[index];
                    final available = service.route != null;
                    return _ServiceTile(
                      service: service,
                      available: available,
                      onTap: () => _openService(context, service),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Text(context.tr('categories'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            categoryState.when(
              loading: () => const SizedBox(height: 44, child: Center(child: LinearProgressIndicator())),
              error: (error, _) => Row(
                children: [
                  Expanded(child: Text(context.tr('categories_load_error'), style: Theme.of(context).textTheme.bodySmall)),
                  IconButton(
                    tooltip: context.tr('retry'),
                    onPressed: () => ref.invalidate(categoriesProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              data: (cats) => cats.isEmpty
                  ? Text(context.tr('categories_empty'), style: Theme.of(context).textTheme.bodySmall)
                  : SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
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
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Text(context.tr('recent'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 218,
              child: ref.watch(recentProductsProvider).when(
                    loading: () => const LoadingView(),
                    error: (_, __) => _InlineLoadError(
                      message: context.tr('home_products_error'),
                      onRetry: () => ref.invalidate(recentProductsProvider),
                    ),
                    data: (products) => products.isEmpty
                        ? EmptyView(
                            message: context.tr('home_products_empty'),
                            icon: Icons.inventory_2_outlined,
                            actionLabel: canCreateListing ? context.tr('add_product') : null,
                            onAction: canCreateListing ? () => context.push('/my-products/new') : null,
                          )
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final p in products)
                                SizedBox(width: 170, child: Padding(padding: const EdgeInsets.only(right: 12), child: ProductCard(p))),
                            ],
                          ),
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

class _HomeService {
  final String titleKey;
  final IconData icon;
  final String? route;

  const _HomeService(this.titleKey, this.icon, {this.route});
}

class _ServiceTile extends StatelessWidget {
  final _HomeService service;
  final bool available;
  final VoidCallback onTap;

  const _ServiceTile({required this.service, required this.available, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(service.icon, size: 22, color: scheme.primary),
              const SizedBox(height: 4),
              Text(
                context.tr(service.titleKey),
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.1),
              ),
              if (!available)
                Text(
                  context.tr('action_planned'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).disabledColor, fontSize: 9),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerFallback extends StatelessWidget {
  final VoidCallback onTap;

  const _BannerFallback({required this.onTap});

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.forest, AppColors.green],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/branding/hosil_x_app_icon.png', width: 42, height: 42, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('banner_fallback_title'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(context.tr('banner_fallback_body'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            )),
            const Icon(Icons.chevron_right, color: Colors.white),
          ]),
        ),
      );
}

class _InlineLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
            IconButton(
              tooltip: context.tr('retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
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
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final bannerHeight = (120 * textScale).clamp(120, 180).toDouble();
    return Column(children: [
        SizedBox(
          height: bannerHeight,
          child: PageView(
            onPageChanged: (v) => setState(() => _i = v),
            children: [
              for (final b in widget.list)
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                  onTap: () => widget.onTap(b),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(fit: StackFit.expand, children: [
                      ProductImage(b.imageUrl),
                      Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Color(0xCC000000), Colors.transparent]))),
                      Positioned(left: 12, right: 12, bottom: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1.15)),
                        if (b.subtitle != null && b.subtitle!.isNotEmpty)
                          Text(b.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ])),
                    ]),
                  ),
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
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: Theme.of(context).colorScheme.primary.withValues(alpha: k == _i ? 1 : 0.25))),
            ]),
          ),
      ]);
  }
}
