import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/stage8_models.dart';

class PlannerRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<List<Goal>> goals(String uid) async {
    final r = await _c.from('tasks').select('id,title,description,due_at,done').eq('user_id', uid).order('due_at');
    return (r as List).map((e) => Goal.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> addGoal(String uid, String title, String? note, DateTime due) async => _c.from('tasks').insert({
        'user_id': uid, 'title': title.trim(), 'description': (note ?? '').trim().isEmpty ? null : note!.trim(), 'due_at': due.toUtc().toIso8601String()});
  Future<void> setDone(String id, bool done) async => _c.from('tasks').update({'done': done}).eq('id', id);
  Future<void> deleteGoal(String id) async => _c.from('tasks').delete().eq('id', id);

  Future<List<FinEntry>> entries(String uid) async {
    final r = await _c.from('finance_entries').select('id,kind,category,amount,currency,planned,entry_date,note').eq('user_id', uid)
        .order('entry_date', ascending: false).limit(300);
    return (r as List).map((e) => FinEntry.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> addEntry(String uid, Map<String, dynamic> data) async => _c.from('finance_entries').insert({...data, 'user_id': uid});
  Future<void> deleteEntry(String id) async => _c.from('finance_entries').delete().eq('id', id);
}
