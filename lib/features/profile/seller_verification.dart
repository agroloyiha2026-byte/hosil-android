import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';

final sellerVerificationStatusProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, userId) async {
  final row = await SupabaseService.client
      .from('seller_verifications')
      .select('status')
      .eq('user_id', userId)
      .maybeSingle();
  return row?['status'] as String?;
});

final pendingSellerVerificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from('seller_verifications')
      .select('user_id,status,requested_at,profiles!inner(full_name,region,farm_name)')
      .eq('status', 'pending')
      .order('requested_at');
  return List<Map<String, dynamic>>.from(rows);
});

Future<void> requestSellerVerification(String userId, WidgetRef ref) async {
  await SupabaseService.client.rpc('request_seller_verification');
  ref.invalidate(sellerVerificationStatusProvider(userId));
  ref.invalidate(pendingSellerVerificationsProvider);
}

Future<void> reviewSellerVerification(String userId, String status, WidgetRef ref) async {
  await SupabaseService.client.rpc('review_seller_verification', params: {
    'p_user_id': userId,
    'p_status': status,
  });
  ref.invalidate(pendingSellerVerificationsProvider);
  ref.invalidate(sellerVerificationStatusProvider(userId));
}
