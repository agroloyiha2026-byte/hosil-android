import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import 'fieldbook_entry.dart';

class FieldbookRepository {
  String _storageKey(String userId) => 'hosil.fieldbook.$userId.v1';

  String createId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<List<FieldbookEntry>> loadLocal(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey(userId));
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Invalid local field journal data');
    return decoded
        .cast<Map<String, dynamic>>()
        .map(FieldbookEntry.fromLocalMap)
        .toList(growable: true);
  }

  Future<void> saveLocal(String userId, List<FieldbookEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    final success = await preferences.setString(
      _storageKey(userId),
      jsonEncode(entries.map((entry) => entry.toLocalMap()).toList()),
    );
    if (!success) throw StateError('Could not persist field journal locally');
  }

  Future<List<FieldbookEntry>> sync(String userId, List<FieldbookEntry> localEntries) async {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    final client = SupabaseService.client;
    var current = List<FieldbookEntry>.of(localEntries);

    for (final entry in current.where((item) => !item.synced).toList()) {
      final result = await client.rpc('sync_fieldbook_entry', params: {
        'p_client_id': entry.id,
        'p_updated_at': entry.updatedAt.toUtc().toIso8601String(),
        'p_entry': entry.toRemoteMap(),
      });
      final remoteEntry = FieldbookEntry.fromRemoteMap(Map<String, dynamic>.from(result as Map));
      current = [
        for (final item in current)
          if (item.id == remoteEntry.id) remoteEntry else item,
      ];
      await saveLocal(userId, current);
    }

    final rows = await client
        .from('fieldbook_entries')
        .select('client_id,crop_type,activity_type,entry_date,quantity,unit,amount,currency,note,deleted,updated_at')
        .eq('user_id', userId)
        .order('entry_date', ascending: false);
    final merged = <String, FieldbookEntry>{};
    for (final item in current) {
      if (!item.synced) merged[item.id] = item;
    }
    for (final row in rows as List) {
      final remote = FieldbookEntry.fromRemoteMap(Map<String, dynamic>.from(row as Map));
      final local = merged[remote.id];
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) merged[remote.id] = remote;
    }
    final result = merged.values.toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
    await saveLocal(userId, result);
    return result;
  }
}
