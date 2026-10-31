import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../profile/seller_verification.dart';

class AdminSellerVerificationScreen extends ConsumerWidget {
  const AdminSellerVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(context.tr('seller_verification_request'))),
        body: AsyncValueView<List<Map<String, dynamic>>>(
          value: ref.watch(pendingSellerVerificationsProvider),
          onRetry: () => ref.invalidate(pendingSellerVerificationsProvider),
          data: (items) => items.isEmpty
              ? EmptyView(message: context.tr('seller_verification_empty'), icon: Icons.verified_user_outlined)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final profile = item['profiles'] as Map<String, dynamic>? ?? const {};
                    final userId = item['user_id'] as String;
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((profile['full_name'] as String?)?.trim().isNotEmpty == true
                              ? profile['full_name'] as String
                              : userId, style: Theme.of(context).textTheme.titleMedium),
                          if ((profile['farm_name'] as String?)?.isNotEmpty == true)
                            Text(profile['farm_name'] as String),
                          if ((profile['region'] as String?)?.isNotEmpty == true)
                            Text(profile['region'] as String),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    await reviewSellerVerification(userId, 'rejected', ref);
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(errText(context, error))),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.close),
                                label: Text(context.tr('seller_verification_rejected')),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  try {
                                    await reviewSellerVerification(userId, 'verified', ref);
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(errText(context, error))),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.verified_outlined),
                                label: Text(context.tr('seller_verified')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      );
}
