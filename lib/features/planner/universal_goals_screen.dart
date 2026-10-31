import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/widgets/widgets.dart';
import '../admin/admin_widgets.dart' show confirmDelete;
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import 'planner_providers.dart';
import 'universal_goal.dart';

const _goalCategories = [
  'financial',
  'farming',
  'business',
  'equipment',
  'learning',
  'personal',
  'other',
];
const _goalStatuses = ['planned', 'active', 'completed', 'cancelled'];

class UniversalGoalsScreen extends ConsumerStatefulWidget {
  const UniversalGoalsScreen({super.key});

  @override
  ConsumerState<UniversalGoalsScreen> createState() =>
      _UniversalGoalsScreenState();
}

class _UniversalGoalsScreenState extends ConsumerState<UniversalGoalsScreen> {
  final _search = TextEditingController();
  String? _categoryFilter, _statusFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(universalGoalsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errText(context, error))),
        );
      }
    }
  }

  Future<void> _openEditor({UniversalGoal? goal}) async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null) return;
    final title = TextEditingController(text: goal?.title ?? '');
    final description = TextEditingController(text: goal?.description ?? '');
    final crop = TextEditingController(text: goal?.cropType ?? '');
    final target =
        TextEditingController(text: goal?.targetValue?.toString() ?? '');
    final current = TextEditingController(text: '${goal?.currentValue ?? 0}');
    final manual = TextEditingController(text: '${goal?.manualProgress ?? 0}');
    final unit = TextEditingController(text: goal?.unit ?? '');
    final formKey = GlobalKey<FormState>();
    var category = goal?.category ?? 'other';
    var priority = goal?.priority ?? 'medium';
    var progressMode = goal?.progressMode ?? 'tasks';
    var currency = goal?.currency ?? 'UZS';
    var start = goal?.startDate ?? DateTime.now();
    var due = goal?.dueDate;
    var busy = false;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    sheetContext.tr(goal == null ? 'goal_create' : 'goal_edit'),
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: title,
                    maxLength: 160,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? sheetContext.tr('goal_title_required')
                        : null,
                    decoration: InputDecoration(
                        labelText: sheetContext.tr('universal_goal_name')),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: description,
                    maxLines: 2,
                    decoration: InputDecoration(
                        labelText: sheetContext.tr('universal_goal_note')),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: InputDecoration(
                        labelText: sheetContext.tr('goal_category')),
                    items: [
                      for (final value in _goalCategories)
                        DropdownMenuItem(
                            value: value,
                            child: Text(sheetContext.tr('goal_cat_$value'))),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => category = value ?? 'other'),
                  ),
                  if (category == 'farming') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: crop,
                      decoration: InputDecoration(
                          labelText: sheetContext.tr('goal_crop')),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: InputDecoration(
                        labelText: sheetContext.tr('goal_priority')),
                    items: [
                      for (final value in const ['low', 'medium', 'high'])
                        DropdownMenuItem(
                            value: value,
                            child:
                                Text(sheetContext.tr('goal_priority_$value'))),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => priority = value ?? 'medium'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: progressMode,
                    decoration: InputDecoration(
                        labelText: sheetContext.tr('goal_progress_type')),
                    items: [
                      for (final value in const ['metric', 'tasks', 'manual'])
                        DropdownMenuItem(
                            value: value,
                            child:
                                Text(sheetContext.tr('goal_progress_$value'))),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => progressMode = value ?? 'tasks'),
                  ),
                  if (progressMode == 'metric') ...[
                    const SizedBox(height: 10),
                    if (category == 'financial')
                      DropdownButtonFormField<String>(
                        value: currency,
                        decoration: InputDecoration(
                            labelText: sheetContext.tr('currency')),
                        items: const [
                          DropdownMenuItem(value: 'UZS', child: Text('UZS')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => currency = value ?? 'UZS'),
                      ),
                    if (category != 'financial')
                      TextField(
                        controller: unit,
                        decoration: InputDecoration(
                            labelText: sheetContext.tr('goal_unit')),
                      ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                        controller: target,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          final number = _number(value);
                          return number == null || number <= 0
                              ? sheetContext.tr('goal_target_invalid')
                              : null;
                        },
                        decoration: InputDecoration(
                            labelText:
                                sheetContext.tr('universal_goal_target')),
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextFormField(
                        controller: current,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) => _number(value) == null
                            ? sheetContext.tr('goal_progress_invalid')
                            : null,
                        decoration: InputDecoration(
                            labelText: sheetContext.tr('goal_current')),
                      )),
                    ]),
                  ],
                  if (progressMode == 'manual') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: manual,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        final number = _number(value);
                        return number == null || number > 100
                            ? sheetContext.tr('goal_progress_invalid')
                            : null;
                      },
                      decoration: InputDecoration(
                          labelText: sheetContext.tr('goal_progress_percent')),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final value = await showDatePicker(
                          context: sheetContext,
                          initialDate: start,
                          firstDate: DateTime(2000),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (value != null && sheetContext.mounted)
                          setSheetState(() => start = value);
                      },
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: Text(
                          '${sheetContext.tr('goal_start')}: ${_date(start)}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final value = await showDatePicker(
                          context: sheetContext,
                          initialDate: due ?? start,
                          firstDate: start,
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (value != null && sheetContext.mounted)
                          setSheetState(() => due = value);
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(due == null
                          ? sheetContext.tr('universal_goal_due_optional')
                          : '${sheetContext.tr('goal_due')}: ${_date(due!)}'),
                    ),
                  ]),
                  if (errorText != null) ErrorText(errorText),
                  const SizedBox(height: 10),
                  AppButton(
                    label: sheetContext.tr('save'),
                    loading: busy,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      setSheetState(() {
                        busy = true;
                        errorText = null;
                      });
                      try {
                        await ref.read(universalGoalRepoProvider).save(
                              userId: userId,
                              id: goal?.id,
                              title: title.text,
                              description: description.text,
                              category: category,
                              startDate: start,
                              dueDate: due,
                              priority: priority,
                              progressMode: progressMode,
                              targetValue: target.text,
                              currentValue: current.text,
                              manualProgress: manual.text,
                              unit: unit.text,
                              currency: currency,
                              cropType: crop.text,
                            );
                        ref.invalidate(universalGoalsProvider);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      } catch (error) {
                        if (sheetContext.mounted) {
                          setSheetState(() {
                            busy = false;
                            errorText = error is FormatException
                                ? sheetContext.tr(error.message.toString())
                                : errText(sheetContext, error);
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    title.dispose();
    description.dispose();
    crop.dispose();
    target.dispose();
    current.dispose();
    manual.dispose();
    unit.dispose();
  }

  Future<void> _showDetails(UniversalGoal goal) async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null) return;
    var tasksFuture =
        ref.read(universalGoalRepoProvider).tasks(userId, goal.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * .78),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(goal.title,
                    style: Theme.of(sheetContext).textTheme.titleLarge),
                if ((goal.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(goal.description!),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: tasksFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return ErrorView(error: snapshot.error!);
                      if (!snapshot.hasData) return const LoadingView();
                      final tasks = snapshot.data!;
                      final value = goal.progress(
                        taskCount: tasks.length,
                        completedTasks:
                            tasks.where((task) => task['done'] == true).length,
                      );
                      return ListView(children: [
                        if (value != null) ...[
                          LinearProgressIndicator(value: value),
                          const SizedBox(height: 8),
                          Text('${(value * 100).round()}%'),
                        ],
                        if (tasks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(sheetContext.tr('goal_tasks_empty'),
                                textAlign: TextAlign.center),
                          ),
                        for (final task in tasks)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Checkbox(
                              value: task['done'] == true,
                              onChanged: (checked) async {
                                await _run(() => ref
                                    .read(universalGoalRepoProvider)
                                    .setTaskDone(task['id'] as String,
                                        checked ?? false));
                                if (sheetContext.mounted)
                                  setSheetState(() {
                                    tasksFuture = ref
                                        .read(universalGoalRepoProvider)
                                        .tasks(userId, goal.id);
                                  });
                              },
                            ),
                            title: Text(task['title'] as String? ?? ''),
                            subtitle: task['due_at'] == null
                                ? null
                                : Text((task['due_at'] as String)
                                    .substring(0, 10)),
                            trailing: IconButton(
                              tooltip: sheetContext.tr('goal_task_unlink'),
                              icon: const Icon(Icons.link_off_outlined),
                              onPressed: () async {
                                await _run(() => ref
                                    .read(universalGoalRepoProvider)
                                    .unlinkTask(
                                        userId, task['link_id'] as String));
                                if (sheetContext.mounted)
                                  setSheetState(() {
                                    tasksFuture = ref
                                        .read(universalGoalRepoProvider)
                                        .tasks(userId, goal.id);
                                  });
                              },
                            ),
                          ),
                      ]);
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await _addTask(sheetContext, goal);
                    if (sheetContext.mounted) {
                      setSheetState(() {
                        tasksFuture = ref
                            .read(universalGoalRepoProvider)
                            .tasks(userId, goal.id);
                      });
                    }
                  },
                  icon: const Icon(Icons.add_task),
                  label: Text(sheetContext.tr('goal_task_add')),
                ),
                TextButton.icon(
                  onPressed: () => _showHistory(sheetContext, userId, goal),
                  icon: const Icon(Icons.history),
                  label: Text(sheetContext.tr('goal_history')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showHistory(
      BuildContext context, String userId, UniversalGoal goal) async {
    late final List<Map<String, dynamic>> events;
    try {
      events =
          await ref.read(universalGoalRepoProvider).history(userId, goal.id);
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errText(context, error))),
        );
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('goal_history')),
        content: SizedBox(
          width: 420,
          child: events.isEmpty
              ? Text(dialogContext.tr('goal_history_empty'))
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final event in events)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(dialogContext
                            .tr('goal_event_${event['event_type']}')),
                        subtitle: Text((event['created_at'] as String)
                            .replaceFirst('T', ' ')
                            .substring(0, 16)),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('close'))),
        ],
      ),
    );
  }

  Future<void> _addTask(BuildContext context, UniversalGoal goal) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('goal_task_add')),
        content: Form(
          key: form,
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: title,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? dialogContext.tr('goal_task_title_required')
                  : null,
              decoration: InputDecoration(
                  labelText: dialogContext.tr('goal_task_title')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: description,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: dialogContext.tr('universal_goal_note')),
            ),
          ])),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate())
                Navigator.pop(dialogContext, true);
            },
            child: Text(dialogContext.tr('save')),
          ),
        ],
      ),
    );
    if (saved == true) {
      await _run(() => ref.read(universalGoalRepoProvider).addTask(
            goalId: goal.id,
            title: title.text,
            description: description.text,
          ));
    }
    title.dispose();
    description.dispose();
  }

  Future<void> _editProgress(UniversalGoal goal) async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null || goal.progressMode == 'tasks') return;
    final controller = TextEditingController(
      text: goal.progressMode == 'manual'
          ? '${goal.manualProgress}'
          : '${goal.currentValue}',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('goal_progress_update')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: goal.progressMode == 'manual'
                ? dialogContext.tr('goal_progress_percent')
                : dialogContext.tr('goal_current'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('cancel'))),
          FilledButton(
            onPressed: () {
              final value = _number(controller.text);
              if (value != null &&
                  value >= 0 &&
                  (goal.progressMode != 'manual' || value <= 100)) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: Text(dialogContext.tr('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      await _run(() => ref.read(universalGoalRepoProvider).updateProgress(
            userId: userId,
            goalId: goal.id,
            progressMode: goal.progressMode,
            value: result,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(sessionProvider).user?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('goals_title')),
        actions: [
          IconButton(
            tooltip: context.tr('goal_legacy_financial'),
            onPressed: () => context.push('/goals/savings'),
            icon: const Icon(Icons.savings_outlined),
          ),
          IconButton(
            tooltip: context.tr('task_list'),
            onPressed: () => context.push('/tasks'),
            icon: const Icon(Icons.checklist_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(context.tr('universal_goal_create')),
      ),
      body: userId == null
          ? EmptyView(message: context.tr('error_auth'))
          : AsyncValueView<List<UniversalGoal>>(
              value: ref.watch(universalGoalsProvider),
              onRetry: () => ref.invalidate(universalGoalsProvider),
              isEmpty: (goals) => goals.isEmpty,
              data: (goals) {
                final filtered = goals.where((goal) {
                  final query = _search.text.trim().toLowerCase();
                  return (_categoryFilter == null ||
                          goal.category == _categoryFilter) &&
                      (_statusFilter == null || goal.status == _statusFilter) &&
                      (query.isEmpty ||
                          goal.title.toLowerCase().contains(query) ||
                          (goal.description ?? '')
                              .toLowerCase()
                              .contains(query));
                }).toList();
                final active =
                    goals.where((goal) => goal.status == 'active').length;
                final completed =
                    goals.where((goal) => goal.status == 'completed').length;
                final dueSoon = goals
                    .where((goal) =>
                        goal.status == 'active' &&
                        goal.dueDate != null &&
                        !goal.dueDate!.isBefore(DateTime.now()) &&
                        goal.dueDate!.difference(DateTime.now()).inDays <= 7)
                    .length;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _CountChip(
                          label: context.tr('goal_count'), count: goals.length),
                      _CountChip(
                          label: context.tr('goal_active_count'),
                          count: active),
                      _CountChip(
                          label: context.tr('goal_completed_count'),
                          count: completed),
                      _CountChip(
                          label: context.tr('goal_due_soon_count'),
                          count: dueSoon),
                    ]),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: context.tr('goal_search'),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: DropdownButtonFormField<String?>(
                        value: _categoryFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText: context.tr('goal_category')),
                        items: [
                          DropdownMenuItem<String?>(
                              value: null,
                              child: Text(context.tr('goal_filter_all'))),
                          for (final category in _goalCategories)
                            DropdownMenuItem<String?>(
                                value: category,
                                child: Text(context.tr('goal_cat_$category'))),
                        ],
                        onChanged: (value) =>
                            setState(() => _categoryFilter = value),
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                          child: DropdownButtonFormField<String?>(
                        value: _statusFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText: context.tr('goal_status')),
                        items: [
                          DropdownMenuItem<String?>(
                              value: null,
                              child: Text(context.tr('goal_filter_all'))),
                          for (final status in _goalStatuses)
                            DropdownMenuItem<String?>(
                                value: status,
                                child: Text(context.tr('goal_status_$status'))),
                        ],
                        onChanged: (value) =>
                            setState(() => _statusFilter = value),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      EmptyView(
                          message: context.tr('goal_filter_empty'),
                          icon: Icons.flag_outlined),
                    for (final goal in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _GoalCard(
                          goal: goal,
                          onTap: () => _showDetails(goal),
                          onEdit: () => _openEditor(goal: goal),
                          onProgress: () => _editProgress(goal),
                          onStatus: (status) => _run(() => ref
                              .read(universalGoalRepoProvider)
                              .setStatus(userId, goal.id, status)),
                          onDelete: () async {
                            final confirmed = await confirmDelete(context);
                            if (confirmed)
                              await _run(() => ref
                                  .read(universalGoalRepoProvider)
                                  .delete(userId, goal.id));
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/goals/savings'),
                      icon: const Icon(Icons.savings_outlined),
                      label: Text(context.tr('goal_legacy_financial')),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final UniversalGoal goal;
  final VoidCallback onTap, onEdit, onProgress, onDelete;
  final ValueChanged<String> onStatus;
  const _GoalCard({
    required this.goal,
    required this.onTap,
    required this.onEdit,
    required this.onProgress,
    required this.onStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress();
    final overdue = goal.status == 'active' &&
        goal.dueDate != null &&
        goal.dueDate!.isBefore(DateTime.now());
    final amount = goal.progressMode == 'metric' && goal.targetValue != null
        ? '${fmtNum(goal.currentValue)} / ${fmtNum(goal.targetValue!)} '
                '${goal.category == 'financial' ? goal.currency ?? '' : goal.unit ?? ''}'
            .trim()
        : null;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(
            goal.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          )),
          PopupMenuButton<String>(
            tooltip: context.tr('goal_actions'),
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  onEdit();
                  break;
                case 'progress':
                  onProgress();
                  break;
                case 'delete':
                  onDelete();
                  break;
                default:
                  onStatus(action);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(context.tr('edit'))),
              if (goal.progressMode != 'tasks')
                PopupMenuItem(
                    value: 'progress',
                    child: Text(context.tr('goal_progress_update'))),
              for (final status
                  in _goalStatuses.where((status) => status != goal.status))
                PopupMenuItem(
                    value: status,
                    child: Text(context.tr('goal_status_$status'))),
              PopupMenuItem(value: 'delete', child: Text(context.tr('delete'))),
            ],
          ),
        ]),
        Wrap(spacing: 6, runSpacing: 2, children: [
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(context.tr('goal_cat_${goal.category}')),
          ),
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(context
                .tr(overdue ? 'goal_overdue' : 'goal_status_${goal.status}')),
            backgroundColor:
                overdue ? Theme.of(context).colorScheme.errorContainer : null,
          ),
          if (goal.dueDate != null)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('${context.tr('goal_due')}: ${_date(goal.dueDate!)}'),
            ),
        ]),
        if (amount != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(amount),
          ),
        if (progress != null) ...[
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 4),
          Text('${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall),
        ] else
          Text(context.tr('goal_progress_not_set'),
              style: Theme.of(context).textTheme.bodySmall),
        if (goal.category == 'farming' && (goal.cropType ?? '').isNotEmpty)
          Text('${context.tr('goal_crop')}: ${goal.cropType}',
              style: Theme.of(context).textTheme.bodySmall),
        if ((goal.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(goal.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  const _CountChip({required this.label, required this.count});
  @override
  Widget build(BuildContext context) => Chip(
        visualDensity: VisualDensity.compact,
        label: Text('$label: $count'),
      );
}

double? _number(String? raw) {
  final value = double.tryParse(
      (raw ?? '').trim().replaceAll(' ', '').replaceAll(',', '.'));
  return value != null && value.isFinite && value >= 0 ? value : null;
}

String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
