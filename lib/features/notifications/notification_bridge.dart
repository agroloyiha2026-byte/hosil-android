import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/localization/l10n.dart';
import '../../core/notifications/reminder_service.dart';
import '../../core/notifications/push_service.dart';
import '../../core/services/supabase_service.dart';
import '../auth/session_controller.dart';
import '../settings/settings_controller.dart';
import '../stage5_providers.dart';

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  if (!SupabaseService.ready) return 0;
  final r = await SupabaseService.client.from('notifications').select('id').eq('read', false);
  return (r as List).length;
});

/// Yangi bildirishnoma (so'rov, moderatsiya) kelganda telefonda ko'rsatadi. Ilova ishlab turganda ishlaydi;
/// ilova butunlay yopiq bo'lsa, push-xizmat (Firebase) kerak, u bu yerda yo'q. Talab: migration9 (Realtime).
final realtimeBridgeProvider = Provider<void>((ref) {
  final uid = ref.watch(sessionProvider.select((s) => s.user?.id));
  if (uid == null || !SupabaseService.ready) return;
  final client = SupabaseService.client;
  final ch = client.channel('notif-$uid').onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'notifications',
    filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
    callback: (payload) {
      final r = payload.newRecord;
      if (!PushService.claimNotification(r['id']?.toString())) return;
      final lang = ref.read(settingsProvider).locale.languageCode;
      ReminderService.show(L10n.tr(lang, 'notif_${r['title']}'), r['body'] as String?);
      ref.invalidate(unreadCountProvider);
      ref.invalidate(notificationsProvider);
    },
  ).subscribe();
  ref.onDispose(() => client.removeChannel(ch));
});
