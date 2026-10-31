import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/stage8_models.dart';

class SavingsGoal {
  final String id;
  final String title;
  final String currency;
  final double targetAmount;
  final double savedAmount;
  final DateTime? dueDate;
  final String? note;
  final String? category;
  final String? status;

  SavingsGoal({
    required this.id,
    required this.title,
    required this.currency,
    required this.targetAmount,
    required this.savedAmount,
    this.dueDate,
    this.note,
    this.category,
    this.status,
  }) {
    if (!targetAmount.isFinite || targetAmount <= 0) {
      throw ArgumentError.value(targetAmount, 'targetAmount');
    }
  }

  bool get isCompleted => savedAmount >= targetAmount || status == 'completed';

  double get progressPercent {
    if (!targetAmount.isFinite || targetAmount <= 0) {
      throw ArgumentError.value(targetAmount, 'targetAmount');
    }
    final raw = (savedAmount / targetAmount) * 100.0;
    return raw.clamp(0.0, 100.0);
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) => SavingsGoal(
        id: map['id'] as String,
        title: map['title'] as String,
        currency: (map['currency'] ?? 'UZS') as String,
        targetAmount: ((map['target_amount'] ?? map['targetAmount'] ?? 0) as num).toDouble(),
        savedAmount: ((map['saved_amount'] ?? map['savedAmount'] ?? 0) as num).toDouble(),
        dueDate: map['due_date'] == null ? null : DateTime.parse(map['due_date'] as String),
        note: map['note'] as String?,
        category: map['category'] as String?,
        status: map['status'] as String?,
      );
}

class PlannerRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<List<Goal>> goals(String uid) async {
    final r = await _c.from('tasks').select('id,title,description,due_at,done,status,category,priority,goal_id').eq('user_id', uid).order('due_at');
    return (r as List).map((e) => Goal.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> addGoal(String uid, String title, String? note, DateTime due) async => _c.from('tasks').insert({
        'user_id': uid,
        'title': title.trim(),
        'description': (note ?? '').trim().isEmpty ? null : note!.trim(),
        'due_at': due.toUtc().toIso8601String(),
      'done': false,
      'status': 'pending',
      });
  Future<void> setDone(String id, bool done) async => _c.from('tasks').update({'done': done, 'status': done ? 'completed' : 'pending'}).eq('id', id);
  Future<void> deleteGoal(String id) async => _c.from('tasks').delete().eq('id', id);

  Future<List<FinEntry>> entries(String uid) async {
    final r = await _c.from('finance_entries').select('id,kind,category,amount,currency,planned,entry_date,note').eq('user_id', uid)
        .order('entry_date', ascending: false).limit(300);
    return (r as List).map((e) => FinEntry.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> addEntry(String uid, Map<String, dynamic> data) async => _c.from('finance_entries').insert({...data, 'user_id': uid});
  Future<void> deleteEntry(String id) async => _c.from('finance_entries').delete().eq('id', id);

  Future<List<SavingsGoal>> savingsGoals(String uid) async {
    final rows = await _c
        .from('financial_goals')
        .select('id,title,target_amount,saved_amount,currency,due_date,note')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (rows as List).map((row) => SavingsGoal.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<void> addSavingsGoal({
    required String userId,
    required String title,
    required double targetAmount,
    required String currency,
    DateTime? dueDate,
    String? note,
  }) async {
    await _c.from('financial_goals').insert({
      'user_id': userId,
      'title': title.trim(),
      'target_amount': targetAmount,
      'currency': currency,
      'due_date': dueDate?.toIso8601String().substring(0, 10),
      'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
    });
  }

  Future<void> setSavingsAmount(String userId, String id, double savedAmount) async {
    if (!savedAmount.isFinite || savedAmount < 0) throw ArgumentError.value(savedAmount, 'savedAmount');
    final rows = await _c.from('financial_goals').update({
        'saved_amount': savedAmount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id).eq('user_id', userId).select('id');
    if ((rows as List).isEmpty) throw const AppError('error_permission');
  }

  Future<void> deleteSavingsGoal(String userId, String id) async {
    final rows = await _c.from('financial_goals').delete().eq('id', id).eq('user_id', userId).select('id');
    if ((rows as List).isEmpty) throw const AppError('error_permission');
  }
}
