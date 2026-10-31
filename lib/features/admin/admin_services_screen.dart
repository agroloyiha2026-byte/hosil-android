import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../services/service_listing.dart';
import '../services/service_providers.dart';

class AdminServicesScreen extends ConsumerWidget {
  const AdminServicesScreen({super.key});

  Future<void> _decide(BuildContext context, WidgetRef ref, ServiceListing listing, String decision) async {
    try {
      await ref.read(serviceRepoProvider).decide(listing.id, decision);
      ref.invalidate(pendingServicesProvider(listing.serviceType));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(context.tr('admin_services'))),
        body: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: context.tr('catalog_equipment')),
                  Tab(text: context.tr('catalog_logistics')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final type in const ['equipment', 'logistics'])
                      AsyncValueView<List<ServiceListing>>(
                        value: ref.watch(pendingServicesProvider(type)),
                        onRetry: () => ref.invalidate(pendingServicesProvider(type)),
                        isEmpty: (items) => items.isEmpty,
                        data: (items) => ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                                  Text(item.region, style: Theme.of(context).textTheme.bodySmall),
                                  const SizedBox(height: 6),
                                  Text(item.description),
                                  if (item.priceAmount != null)
                                    Text('${fmtNum(item.priceAmount!)} ${item.currency}${item.priceUnit == null ? '' : ' / ${item.priceUnit}'}'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AppButton(
                                          label: context.tr('approve'),
                                          onPressed: () => _decide(context, ref, item, 'active'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: AppButton(
                                          label: context.tr('reject'),
                                          outlined: true,
                                          onPressed: () => _decide(context, ref, item, 'rejected'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
