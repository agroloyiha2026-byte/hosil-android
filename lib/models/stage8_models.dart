class Goal {
  final String id, title;
  final String? description;
  final DateTime dueAt;
  final bool done;
  final String status;
  final String? category;
  final String? priority;
  final String? goalId;

  const Goal(
    this.id,
    this.title,
    this.description,
    this.dueAt,
    this.done, {
    this.status = 'pending',
    this.category,
    this.priority,
    this.goalId,
  });

  factory Goal.fromMap(Map<String, dynamic> m) {
    final rawStatus = (m['status'] ?? m['state'] ?? 'pending') as String;
    final dueValue = m['due_at'] ?? m['dueAt'];
    final dueAt = dueValue == null
        ? DateTime.now()
        : DateTime.parse(dueValue as String).toLocal();
    final done = (m['done'] ?? m['is_done'] ?? false) as bool ||
        rawStatus == 'completed' ||
        rawStatus == 'done';

    return Goal(
      m['id'] as String,
      m['title'] as String,
      m['description'] as String?,
      dueAt,
      done,
      status: rawStatus,
      category: m['category'] as String?,
      priority: m['priority'] as String?,
      goalId: m['goal_id'] as String? ?? m['goalId'] as String?,
    );
  }
}

extension GoalStatusX on Goal {
  bool get isCompleted => done || status == 'completed' || status == 'done';
}

/// Maqsadlarni guruhlaydi: overdue | today | upcoming | done.
Map<String, List<Goal>> groupGoals(List<Goal> all, DateTime now) {
  final out = {
    'overdue': <Goal>[],
    'today': <Goal>[],
    'upcoming': <Goal>[],
    'done': <Goal>[]
  };
  final dayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
  for (final g in all) {
    if (g.isCompleted) {
      out['done']!.add(g);
    } else if (g.dueAt.isBefore(now)) {
      out['overdue']!.add(g);
    } else if (!g.dueAt.isAfter(dayEnd)) {
      out['today']!.add(g);
    } else {
      out['upcoming']!.add(g);
    }
  }
  return out;
}

class FinEntry {
  final String id, kind, category, currency, entryDate;
  final double amount;
  final bool planned;
  final String? note;
  const FinEntry(this.id, this.kind, this.category, this.amount, this.currency,
      this.planned, this.entryDate, this.note);
  factory FinEntry.fromMap(Map<String, dynamic> m) => FinEntry(
      m['id'] as String,
      m['kind'] as String,
      m['category'] as String,
      (m['amount'] as num).toDouble(),
      m['currency'] as String,
      m['planned'] as bool,
      m['entry_date'] as String,
      m['note'] as String?);
}

const financeIncomeCategories = [
  'harvest_sale',
  'product_trade',
  'service_income',
  'warehouse_income',
  'equipment_rental_income',
  'subsidy',
  'other_income',
];

const financeExpenseCategories = [
  'seeds',
  'fertilizer',
  'crop_protection',
  'fuel',
  'irrigation',
  'labor',
  'equipment_repair',
  'storage_logistics',
  'utilities',
  'other_expense',
];

List<String> financeCategoriesForKind(String kind) => switch (kind) {
      'income' => financeIncomeCategories,
      'expense' => financeExpenseCategories,
      _ => throw ArgumentError.value(kind, 'kind'),
    };

/// Valyutalar aralashtirilmaydi; rejalashtirilgan yozuvlar hisobga kirmaydi.
Map<String, ({double inc, double exp})> totalsByCurrency(
    List<FinEntry> entries) {
  final out = <String, ({double inc, double exp})>{};
  for (final e in entries) {
    if (e.planned) continue;
    final cur = out[e.currency] ?? (inc: 0.0, exp: 0.0);
    out[e.currency] = e.kind == 'income'
        ? (inc: cur.inc + e.amount, exp: cur.exp)
        : (inc: cur.inc, exp: cur.exp + e.amount);
  }
  return out;
}
