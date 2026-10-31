import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import 'universal_goal.dart';

class UniversalGoalRepository {
  get _client {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<List<UniversalGoal>> list(String userId) async {
    final rows = await _client.from('user_goals').select(
      'id,user_id,title,description,category,start_date,due_date,priority,status,progress_mode,target_value,current_value,manual_progress,unit,currency,crop_type',
    ).eq('user_id', userId).order('due_date').order('created_at', ascending: false);
    final goals = (rows as List)
        .map((row) => UniversalGoal.fromMap(row as Map<String, dynamic>))
        .toList();
    if (goals.isEmpty) return goals;
    final links = await _client.from('goal_task_links').select(
      'goal_id,task:tasks!inner(done)',
    ).eq('owner_id', userId).inFilter('goal_id', goals.map((goal) => goal.id).toList());
    final counts = <String, ({int all, int done})>{};
    for (final row in links as List) {
      final link = row as Map<String, dynamic>;
      final task = link['task'];
      if (task is! Map<String, dynamic>) continue;
      final id = link['goal_id'] as String;
      final current = counts[id] ?? (all: 0, done: 0);
      counts[id] = (
        all: current.all + 1,
        done: current.done + (task['done'] == true ? 1 : 0),
      );
    }
    return goals.map((goal) {
      final count = counts[goal.id] ?? (all: 0, done: 0);
      return goal.withTaskCounts(count.all, count.done);
    }).toList();
  }

  Future<void> save({
    required String userId,
    String? id,
    required String title,
    required String description,
    required String category,
    required DateTime startDate,
    DateTime? dueDate,
    required String priority,
    required String progressMode,
    String? targetValue,
    String currentValue = '0',
    String manualProgress = '0',
    String unit = '',
    String currency = 'UZS',
    String cropType = '',
  }) async {
    final target = _parseNonNegative(targetValue ?? '', required: progressMode == 'metric');
    final current = _parseNonNegative(currentValue);
    final manual = _parseNonNegative(manualProgress);
    if (progressMode == 'metric' && (target == null || target <= 0)) {
      throw const FormatException('goal_target_invalid');
    }
    if (progressMode == 'manual' && (manual == null || manual > 100)) {
      throw const FormatException('goal_progress_invalid');
    }
    if (current == null) throw const FormatException('goal_progress_invalid');
    if (dueDate != null && dueDate.isBefore(DateTime(startDate.year, startDate.month, startDate.day))) {
      throw const FormatException('goal_date_invalid');
    }
    if (!const {'financial', 'farming', 'business', 'equipment', 'learning', 'personal', 'other'}.contains(category)) {
      throw const FormatException('goal_category_invalid');
    }
    if (!const {'metric', 'tasks', 'manual'}.contains(progressMode)) {
      throw const FormatException('goal_progress_invalid');
    }
    if (!const {'low', 'medium', 'high'}.contains(priority)) {
      throw const FormatException('goal_priority_invalid');
    }
    if (category == 'financial' && !const {'UZS', 'USD'}.contains(currency)) {
      throw const FormatException('goal_currency_invalid');
    }

    final values = <String, dynamic>{
      'user_id': userId,
      'title': title.trim(),
      'description': _nullable(description),
      'category': category,
      'start_date': _date(startDate),
      'due_date': dueDate == null ? null : _date(dueDate),
      'priority': priority,
      'progress_mode': progressMode,
      'target_value': progressMode == 'metric' ? target : null,
      'current_value': current,
      'manual_progress': progressMode == 'manual' ? manual : 0,
      'unit': _nullable(category == 'financial' ? currency : unit),
      'currency': category == 'financial' ? currency : null,
      'crop_type': _nullable(cropType),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (values['title'].toString().isEmpty) throw const FormatException('goal_title_required');
    if (id == null) {
      await _client.from('user_goals').insert(values);
    } else {
      final rows = await _client.from('user_goals').update(values)
          .eq('id', id).eq('user_id', userId).select('id');
      if ((rows as List).isEmpty) throw const AppError('error_permission');
    }
  }

  Future<void> updateProgress({
    required String userId,
    required String goalId,
    required String progressMode,
    required double value,
  }) async {
    if (!value.isFinite || value < 0 || (progressMode == 'manual' && value > 100)) {
      throw const FormatException('goal_progress_invalid');
    }
    final field = progressMode == 'manual' ? 'manual_progress' : 'current_value';
    final rows = await _client.from('user_goals').update({
      field: value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', goalId).eq('user_id', userId).select('id');
    if ((rows as List).isEmpty) throw const AppError('error_permission');
  }

  Future<void> setStatus(String userId, String goalId, String status) async {
    if (!const {'planned', 'active', 'completed', 'cancelled'}.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    final rows = await _client.from('user_goals').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', goalId).eq('user_id', userId).select('id');
    if ((rows as List).isEmpty) throw const AppError('error_permission');
  }

  Future<void> delete(String userId, String goalId) async {
    final rows = await _client.from('user_goals').delete()
        .eq('id', goalId).eq('user_id', userId).select('id');
    if ((rows as List).isEmpty) throw const AppError('error_permission');
  }

  Future<List<Map<String, dynamic>>> tasks(String userId, String goalId) async {
    final rows = await _client.from('goal_task_links').select(
      'id,task:tasks!inner(id,title,description,due_at,done,status)',
    ).eq('owner_id', userId).eq('goal_id', goalId).order('created_at');
    return (rows as List).map((row) {
      final link = row as Map<String, dynamic>;
      final task = link['task'];
      return {
        'link_id': link['id'],
        if (task is Map<String, dynamic>) ...task,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> history(String userId, String goalId) async {
    final rows = await _client.from('user_goal_events')
        .select('event_type,details,created_at')
        .eq('user_id', userId).eq('goal_id', goalId)
        .order('created_at', ascending: false).limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> addTask({
    required String goalId,
    required String title,
    required String description,
    DateTime? dueDate,
  }) async {
    if (title.trim().isEmpty) throw const FormatException('goal_task_title_required');
    await _client.rpc('add_task_to_goal', params: {
      'p_goal_id': goalId,
      'p_title': title.trim(),
      'p_description': _nullable(description),
      'p_due_at': dueDate?.toUtc().toIso8601String(),
    });
  }

  Future<void> setTaskDone(String taskId, bool done) async {
    await _client.from('tasks').update({
      'done': done,
      'status': done ? 'completed' : 'pending',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', taskId);
  }

  Future<void> unlinkTask(String userId, String linkId) async {
    await _client.from('goal_task_links').delete()
        .eq('id', linkId).eq('owner_id', userId);
  }

  double? _parseNonNegative(String value, {bool required = false}) {
    if (value.trim().isEmpty && !required) return 0;
    final number = double.tryParse(value.trim().replaceAll(' ', '').replaceAll(',', '.'));
    return number != null && number.isFinite && number >= 0 ? number : null;
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
