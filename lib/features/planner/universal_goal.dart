class UniversalGoal {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String category;
  final DateTime startDate;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final String progressMode;
  final double? targetValue;
  final double currentValue;
  final double manualProgress;
  final String? unit;
  final String? currency;
  final String? cropType;
  final int taskCount;
  final int completedTaskCount;

  const UniversalGoal({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.startDate,
    required this.priority,
    required this.status,
    required this.progressMode,
    required this.currentValue,
    required this.manualProgress,
    this.description,
    this.dueDate,
    this.targetValue,
    this.unit,
    this.currency,
    this.cropType,
    this.taskCount = 0,
    this.completedTaskCount = 0,
  });

  factory UniversalGoal.fromMap(Map<String, dynamic> row) => UniversalGoal(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        title: row['title'] as String,
        category: row['category'] as String,
        startDate: DateTime.parse(row['start_date'] as String),
        priority: row['priority'] as String? ?? 'medium',
        status: row['status'] as String? ?? 'planned',
        progressMode: row['progress_mode'] as String? ?? 'tasks',
        currentValue: (row['current_value'] as num? ?? 0).toDouble(),
        manualProgress: (row['manual_progress'] as num? ?? 0).toDouble(),
        description: row['description'] as String?,
        dueDate: row['due_date'] == null ? null : DateTime.parse(row['due_date'] as String),
        targetValue: (row['target_value'] as num?)?.toDouble(),
        unit: row['unit'] as String?,
        currency: row['currency'] as String?,
        cropType: row['crop_type'] as String?,
      );

  UniversalGoal withTaskCounts(int total, int completed) => UniversalGoal(
        id: id,
        userId: userId,
        title: title,
        description: description,
        category: category,
        startDate: startDate,
        dueDate: dueDate,
        priority: priority,
        status: status,
        progressMode: progressMode,
        targetValue: targetValue,
        currentValue: currentValue,
        manualProgress: manualProgress,
        unit: unit,
        currency: currency,
        cropType: cropType,
        taskCount: total,
        completedTaskCount: completed,
      );

  double? progress({int? taskCount, int? completedTasks}) {
    switch (progressMode) {
      case 'metric':
        final target = targetValue;
        if (target == null || !target.isFinite || target <= 0 || !currentValue.isFinite) return null;
        return (currentValue / target).clamp(0.0, 1.0).toDouble();
      case 'tasks':
        final total = taskCount ?? this.taskCount;
        final completed = completedTasks ?? completedTaskCount;
        if (total <= 0) return null;
        return (completed / total).clamp(0.0, 1.0).toDouble();
      case 'manual':
        if (!manualProgress.isFinite) return null;
        return (manualProgress / 100).clamp(0.0, 1.0).toDouble();
      default:
        return null;
    }
  }
}
