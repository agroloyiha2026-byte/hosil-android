import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/localization/l10n.dart';
import '../../core/services/supabase_service.dart';
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
    final ad = ref.watch(adsProvider(placement)).valueOrNull;
    if (ad == null) return const SizedBox.shrink();
    final link = ad['link_url'] as String?;
    final safe = link != null && link.startsWith('https://'); // faqat https havolalar
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: safe ? () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(children: [
            AspectRatio(aspectRatio: 16 / 6, child: SizedBox.expand(child: ProductImage(ad['image_url'] as String?))),
            Positioned(left: 10, top: 10, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Text(context.tr('ad_label'), style: const TextStyle(color: Colors.white, fontSize: 11)),
            )),
          ]),
        ),
      ),
    );
  }
}
