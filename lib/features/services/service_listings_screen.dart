import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../market/product_card.dart';
import 'service_listing.dart';
import 'service_providers.dart';

class ServiceListingsScreen extends ConsumerStatefulWidget {
  final String type;
  const ServiceListingsScreen({super.key, required this.type});

  @override
  ConsumerState<ServiceListingsScreen> createState() =>
      _ServiceListingsScreenState();
}

class ServiceListingDetailScreen extends ConsumerWidget {
  final String type, id;
  const ServiceListingDetailScreen(
      {super.key, required this.type, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (type: type, id: id);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('catalog_$type'))),
      body: AsyncValueView<ServiceListing?>(
        value: ref.watch(publicServiceListingProvider(key)),
        onRetry: () => ref.invalidate(publicServiceListingProvider(key)),
        data: (listing) {
          if (listing == null)
            return EmptyView(message: context.tr('service_target_unavailable'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                  aspectRatio: 16 / 9, child: ProductImage(listing.imageUrl)),
            ),
            const SizedBox(height: 12),
            AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(listing.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(listing.region,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Text(listing.description),
                  if (listing.priceAmount != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${fmtNum(listing.priceAmount!)} ${listing.currency}'
                      '${listing.priceUnit == null ? '' : ' / ${listing.priceUnit}'}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ])),
            if ((listing.contactPhone ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              AppButton(
                label: context.tr('call_provider'),
                icon: Icons.call_outlined,
                onPressed: () async {
                  try {
                    final opened = await launchUrl(
                        Uri(scheme: 'tel', path: listing.contactPhone));
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('error_generic'))),
                      );
                    }
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('error_generic'))),
                      );
                  }
                },
              ),
            ],
          ]);
        },
      ),
    );
  }
}

class _ServiceListingsScreenState extends ConsumerState<ServiceListingsScreen> {
  bool _showMine = false;

  @override
  Widget build(BuildContext context) {
    final isFarmer = ref.watch(sessionProvider.select((state) =>
        state.profile?.role == 'farmer' || state.profile?.role == 'admin'));
    final listings = _showMine
        ? ref.watch(myServiceListingsProvider(widget.type))
        : ref.watch(serviceListingsProvider(widget.type));
    final provider = _showMine
        ? myServiceListingsProvider(widget.type)
        : serviceListingsProvider(widget.type);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('catalog_${widget.type}')),
        actions: [
          IconButton(
            tooltip: context.tr('add_service_listing'),
            onPressed: isFarmer
                ? () => context.push('/services/new/${widget.type}')
                : null,
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: false, label: Text(context.tr('service_active'))),
                ButtonSegment(
                    value: true, label: Text(context.tr('service_mine'))),
              ],
              selected: {_showMine},
              onSelectionChanged: (value) =>
                  setState(() => _showMine = value.first),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<ServiceListing>>(
              value: listings,
              onRetry: () => ref.invalidate(provider),
              isEmpty: (items) => items.isEmpty,
              data: (items) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(provider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _ServiceCard(
                    listing: items[index],
                    own: _showMine,
                    onDelete: () async {
                      final ownerId = ref.read(sessionProvider).user?.id;
                      if (ownerId == null) return;
                      try {
                        await ref
                            .read(serviceRepoProvider)
                            .deleteOwn(ownerId, items[index].id);
                        ref.invalidate(myServiceListingsProvider(widget.type));
                      } catch (e) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errText(context, e))));
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceListing listing;
  final bool own;
  final VoidCallback onDelete;
  const _ServiceCard(
      {required this.listing, required this.own, required this.onDelete});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                  aspectRatio: 16 / 8, child: ProductImage(listing.imageUrl)),
            ),
            Row(
              children: [
                Expanded(
                    child: Text(listing.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800))),
                if (own)
                  Chip(
                      label:
                          Text(context.tr('service_status_${listing.status}'))),
              ],
            ),
            Text(listing.region, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(listing.description),
            if (listing.priceAmount != null) ...[
              const SizedBox(height: 8),
              Text(
                  '${fmtNum(listing.priceAmount!)} ${listing.currency}${listing.priceUnit == null ? '' : ' / ${listing.priceUnit}'}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary)),
            ],
            if (own && listing.status != 'active')
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: context.tr('delete'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              )
            else if (!own && (listing.contactPhone ?? '').isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final uri = Uri(scheme: 'tel', path: listing.contactPhone);
                    if (!await launchUrl(uri) && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr('error_generic'))));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(errText(context, e))));
                    }
                  }
                },
                icon: const Icon(Icons.call_outlined),
                label: Text(context.tr('call_provider')),
              ),
          ],
        ),
      );
}
