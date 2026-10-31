import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/localization/l10n.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/widgets.dart';
import '../market/product_card.dart';

/// Admin qo'shgan faol reklama (joylashuv: home_top, home_middle, market_top). Tugash sanasi o'tganlari chiqmaydi.
final adsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, placement) async {
  if (!SupabaseService.ready) return null;
  final r = await SupabaseService.client.from('ads').select('title,image_url,link_url').eq('placement', placement).eq('active', true)
      .or('ends_at.is.null,ends_at.gt.${DateTime.now().toUtc().toIso8601String()}').order('created_at', ascending: false).limit(1);
  final l = r as List;
  return l.isEmpty ? null : l.first as Map<String, dynamic>;
});

class AdBanner extends ConsumerWidget {
  final String placement;
  const AdBanner({super.key, required this.placement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adsProvider(placement));
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 76, child: Center(child: LinearProgressIndicator())),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(child: Text(context.tr('ad_load_error'), style: Theme.of(context).textTheme.bodySmall)),
            IconButton(
              tooltip: context.tr('retry'),
              onPressed: () => ref.invalidate(adsProvider(placement)),
              icon: const Icon(Icons.refresh),
            ),
          ]),
        ),
      ),
      data: (ad) {
        if (ad == null) return const SizedBox.shrink();
        final link = ad['link_url'] as String?;
        final uri = link == null ? null : Uri.tryParse(link);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty) {
                  try {
                    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('error_generic'))),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('error_generic'))),
                    );
                  }
                } else {
                  await showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(ad['title'] as String? ?? ''),
                      content: Text(dialogContext.tr('ad_no_link')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext),
                          child: Text(dialogContext.tr('close'))),
                      ],
                    ),
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 3,
                  child: Stack(fit: StackFit.expand, children: [
                    ProductImage(ad['image_url'] as String?),
                    const DecoratedBox(decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Color(0xB8000000), Colors.transparent],
                      ),
                    )),
                    Positioned(
                      left: 10, top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text(context.tr('ad_label'),
                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                    Positioned(
                      left: 12, right: 12, bottom: 10,
                      child: Text(ad['title'] as String? ?? '',
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
