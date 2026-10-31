import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/localization/l10n.dart';
import '../../core/config/env.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../products/product_providers.dart';
import '../products/product_repository.dart';
import 'harvest_passport.dart';
import 'passport_providers.dart';

class PassportsScreen extends ConsumerWidget {
  final String? passportId;
  const PassportsScreen({super.key, this.passportId});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    late final List<MyProduct> products;
    late final List<HarvestPassport> passports;
    try {
      products = await ref.read(myProductsProvider.future);
      passports = await ref.read(harvestPassportsProvider.future);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
      }
      return;
    }
    if (!context.mounted) return;
    final issuedProductIds = passports.where((item) => !item.revoked).map((item) => item.productId).toSet();
    final eligible = products.where((item) =>
        item.status == 'active' && item.moderation == 'approved' && !issuedProductIds.contains(item.product.id)).toList();
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('passport_no_eligible_products'))));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(sheetContext.tr('passport_choose_product'), style: Theme.of(sheetContext).textTheme.titleLarge),
          ),
          for (final item in eligible)
            ListTile(
              leading: const Icon(Icons.eco_outlined),
              title: Text(item.product.title),
              subtitle: Text('${item.product.region} · ${item.product.category}'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await ref.read(passportRepositoryProvider).create(item.product.id);
                  ref.invalidate(harvestPassportsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context, HarvestPassport passport) async {
    try {
      final link = Env.harvestPassportVerificationUrl(passport.id);
      await Share.share('${context.tr('passport_share_intro')}\n$link');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
      }
    }
  }

  Future<void> _copyLink(BuildContext context, String link) async {
    try {
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('passport_link_copied'))),
      );
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errText(context, error))),
      );
    }
  }

  Future<void> _openLink(BuildContext context, String link) async {
    try {
      final opened = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('error_generic'))),
        );
      }
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errText(context, error))),
      );
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, HarvestPassport passport) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('passport_revoke_title')),
        content: Text(dialogContext.tr('passport_revoke_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(dialogContext.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(dialogContext.tr('passport_revoke'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(passportRepositoryProvider).revoke(passport.id);
      ref.invalidate(harvestPassportsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
      }
    }
  }

  Widget _detail(BuildContext context, WidgetRef ref, HarvestPassport passport) {
    final link = Env.harvestPassportVerificationUrl(passport.id);
    final currentUserId = ref.watch(sessionProvider).user?.id;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(passport.productTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('${context.tr('passport_product_type')}: ${passport.productType}'),
              Text('${context.tr('passport_category')}: ${passport.category}'),
              Text('${context.tr('passport_region')}: ${passport.region}'),
              const Divider(height: 24),
              Text('${context.tr('passport_farmer')}: ${passport.farmerName}'),
              Text('${context.tr('passport_region')}: ${passport.farmerRegion}'),
              const SizedBox(height: 8),
              Text('${context.tr('passport_issued')}: ${passport.issuedAt.toLocal().toString().substring(0, 10)}'),
              if (passport.revoked)
                Text('${context.tr('passport_revoked')}: ${passport.revokedAt!.toLocal().toString().substring(0, 10)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (!passport.productPublic && !passport.revoked)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(context.tr('passport_product_unavailable'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              QrImageView(
                data: link,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                semanticsLabel: context.tr('passport_qr_label'),
              ),
              const SizedBox(height: 8),
              SelectableText(link, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              Text(context.tr('passport_quality_disclaimer'), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _share(context, passport),
                icon: const Icon(Icons.share_outlined),
                label: Text(context.tr('passport_share')),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _copyLink(context, link),
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(context.tr('passport_copy_link')),
                  ),
                  TextButton.icon(
                    onPressed: () => _openLink(context, link),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(context.tr('passport_open_link')),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (currentUserId != null && !passport.revoked) ...[
          const SizedBox(height: 12),
          AppButton(
            label: context.tr('passport_revoke'),
            outlined: true,
            onPressed: () => _revoke(context, ref, passport),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(harvestPassportsProvider);
    final farmer = ref.watch(sessionProvider.select((value) =>
        value.profile?.role == 'farmer' || value.profile?.role == 'admin'));
    final title = passportId == null ? context.tr('passport_title') : context.tr('passport_details');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: passportId == null && farmer
          ? FloatingActionButton.extended(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.qr_code_2),
              label: Text(context.tr('passport_create')),
            )
          : null,
      body: !farmer
          ? EmptyView(message: context.tr('passport_farmer_only'))
          : AsyncValueView<List<HarvestPassport>>(
              value: state,
              onRetry: () => ref.invalidate(harvestPassportsProvider),
              isEmpty: (items) => items.isEmpty,
              data: (items) {
                if (passportId != null) {
                  final selected = items.where((item) => item.id == passportId).firstOrNull;
                  return selected == null
                      ? EmptyView(message: context.tr('passport_not_found'))
                      : _detail(context, ref, selected);
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(harvestPassportsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return AppCard(
                        onTap: () => context.push('/passports/${item.id}'),
                        child: Row(
                          children: [
                            Icon(item.revoked ? Icons.qr_code_2 : Icons.verified_outlined,
                                color: item.revoked ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productTitle, style: Theme.of(context).textTheme.titleMedium),
                                  Text(item.revoked
                                      ? context.tr('passport_status_revoked')
                                      : item.productPublic
                                          ? context.tr('passport_status_active')
                                          : context.tr('passport_product_unavailable')),
                                  Text('${context.tr('passport_issued')}: ${item.issuedAt.toLocal().toString().substring(0, 10)}',
                                      style: Theme.of(context).textTheme.bodySmall),
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
              },
            ),
    );
  }
}

extension _FirstPassportOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
