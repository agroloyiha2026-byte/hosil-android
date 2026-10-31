import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import 'planner_providers.dart';
import 'planner_repository.dart';

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null) return;
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController();
    final target = TextEditingController();
    final note = TextEditingController();
    var currency = 'UZS';
    DateTime? dueDate;
    var busy = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 16),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sheetContext.tr('goal_create'), style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  AppTextField(controller: title, label: sheetContext.tr('goal_name'), validator: tv(sheetContext, Validators.required)),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: target,
                    label: sheetContext.tr('goal_target'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final number = double.tryParse((value ?? '').replaceAll(' ', '').replaceAll(',', '.'));
                      return number == null || !number.isFinite || number <= 0
                          ? sheetContext.tr('goal_amount_invalid')
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: InputDecoration(
                      labelText: sheetContext.tr('currency'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'UZS', child: Text('UZS')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                    ],
                    onChanged: (value) => setSheetState(() => currency = value ?? 'UZS'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(controller: note, label: sheetContext.tr('goal_note'), maxLines: 2),
                  TextButton.icon(
                    icon: const Icon(Icons.event_outlined),
                    label: Text(dueDate == null
                        ? sheetContext.tr('goal_due_optional')
                        : '${sheetContext.tr('goal_due')}: ${dueDate!.toLocal().toString().substring(0, 10)}'),
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: sheetContext,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (selected != null && sheetContext.mounted) setSheetState(() => dueDate = selected);
                    },
                  ),
                  if (error != null) ErrorText(error),
                  const SizedBox(height: 8),
                  AppButton(
                    label: sheetContext.tr('save'),
                    loading: busy,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      setSheetState(() { busy = true; error = null; });
                      try {
                        await ref.read(plannerRepoProvider).addSavingsGoal(
                              userId: userId,
                              title: title.text,
                              targetAmount: double.parse(target.text.replaceAll(' ', '').replaceAll(',', '.')),
                              currency: currency,
                              dueDate: dueDate,
                              note: note.text,
                            );
                        ref.invalidate(savingsGoalsProvider);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      } catch (e) {
                        if (sheetContext.mounted) setSheetState(() { busy = false; error = errText(sheetContext, e); });
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
    target.dispose();
    note.dispose();
  }

  Future<void> _updateSavings(BuildContext context, WidgetRef ref, SavingsGoal goal) async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null) return;
    final amount = TextEditingController(text: goal.savedAmount.toString());
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('goal_saved_amount')),
        content: TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: '${dialogContext.tr('goal_saved_amount')} (${goal.currency})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(dialogContext.tr('cancel'))),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(amount.text.trim().replaceAll(' ', '').replaceAll(',', '.'));
              if (parsed != null && parsed.isFinite && parsed >= 0) Navigator.pop(dialogContext, parsed);
            },
            child: Text(dialogContext.tr('save')),
          ),
        ],
      ),
    );
    amount.dispose();
    if (value == null) return;
    try {
      await ref.read(plannerRepoProvider).setSavingsAmount(userId, goal.id, value);
      ref.invalidate(savingsGoalsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider);
    final uid = ref.watch(sessionProvider).user?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('goals_title')),
        actions: [
          IconButton(
            tooltip: context.tr('task_list'),
            onPressed: () => context.push('/tasks'),
            icon: const Icon(Icons.checklist_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.tr('goal_create')),
      ),
      body: uid == null
          ? EmptyView(message: context.tr('error_auth'))
          : AsyncValueView<List<SavingsGoal>>(
              value: goals,
              onRetry: () => ref.invalidate(savingsGoalsProvider),
              isEmpty: (items) => items.isEmpty,
              data: (items) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final goal = items[index];
                  final progress = (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0);
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(goal.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                            IconButton(
                              tooltip: context.tr('delete'),
                              onPressed: () async {
                                final userId = ref.read(sessionProvider).user?.id;
                                if (userId == null) return;
                                try {
                                  await ref.read(plannerRepoProvider).deleteSavingsGoal(userId, goal.id);
                                  ref.invalidate(savingsGoalsProvider);
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        Text('${fmtNum(goal.savedAmount)} / ${fmtNum(goal.targetAmount)} ${goal.currency}'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: progress),
                        if (goal.dueDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('${context.tr('goal_due')}: ${goal.dueDate!.toLocal().toString().substring(0, 10)}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                        if ((goal.note ?? '').isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 6), child: Text(goal.note!)),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _updateSavings(context, ref, goal),
                          icon: const Icon(Icons.savings_outlined),
                          label: Text(context.tr('goal_update_saved')),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
