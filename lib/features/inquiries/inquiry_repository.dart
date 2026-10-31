import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/stage5_models.dart';

class InquiryRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  /// RLS faqat o'zingiz yuborgan yoki o'zingizning mahsulotlaringizga kelgan so'rovlarni qaytaradi.
  Future<List<InquiryItem>> list() async {
    final r = await _c.from('inquiries')
        .select('id,status,buyer_id,offered_price,message,created_at,products(title,seller_id,currency)')
        .order('created_at', ascending: false).limit(100);
    return (r as List).map((e) => InquiryItem.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> setStatus(String id, String status) async {
    await _c.from('inquiries').update({'status': status}).eq('id', id);
  }

  Future<List<ChatMessage>> messages(String inquiryId) async {
    final rows = await _c.from('chat_messages').select('id,inquiry_id,sender_id,body,created_at,read_at')
        .eq('inquiry_id', inquiryId).order('created_at');
    return (rows as List).map((row) => ChatMessage.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<void> sendMessage({required String inquiryId, required String senderId, required String body}) async {
    final text = body.trim();
    if (text.isEmpty || text.length > 4000) throw ArgumentError.value(body, 'body');
    await _c.from('chat_messages').insert({
      'inquiry_id': inquiryId,
      'sender_id': senderId,
      'body': text,
    });
  }

  Future<int> unreadMessageCount(String userId) async {
    final rows = await _c.from('chat_messages').select('id').neq('sender_id', userId).isFilter('read_at', null);
    return (rows as List).length;
  }

  Future<void> markMessagesRead(String inquiryId, String userId) async {
    await _c.from('chat_messages').update({
      'read_at': DateTime.now().toUtc().toIso8601String(),
      'read_by': userId,
    }).eq('inquiry_id', inquiryId).neq('sender_id', userId).isFilter('read_at', null).select('id');
  }
}
