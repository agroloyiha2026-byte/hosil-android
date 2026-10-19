import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import '../../models/stage8_models.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../profile/profile_button.dart';
import 'planner_providers.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  String _fmt(DateTime d) => d.toString().substring(0, 16);

  void _add(BuildContext context, WidgetRef ref) {
    final uid = ref.read(sessionProvider).user?.id;
    if (uid == null) return;
    final form = GlobalKey<FormState>();
    final title = TextEditingController(), note = TextEditingController();
    DateTime? due;
    var busy = false;
    String? err;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.tr('add_goal'), style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          AppTextField(controller: title, label: ctx.tr('goal_title'), validator: tv(ctx, Validators.required)),
          const SizedBox(height: 12),
          AppTextField(controller: note, label: ctx.tr('goal_note'), maxLines: 2),
          const SizedBox(height: 12),
          AppButton(label: due == null ? ctx.tr('pick_datetime') : _fmt(due!), outlined: true, icon: Icons.event, onPressed: () async {
            final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 1095)));
            if (d == null || !ctx.mounted) return;
            final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
            if (t != null) set(() => due = DateTime(d.year, d.month, d.day, t.hour, t.minute));
          }),
          const SizedBox(height: 12),
          ErrorText(err),
          AppButton(label: ctx.tr('save'), loading: busy, onPressed: () async {
            if (!form.currentState!.validate()) return;
            if (due == null) { set(() => err = ctx.tr('v_due')); return; }
            set(() { busy = true; err = null; });
            try {
              await ref.read(plannerRepoProvider).addGoal(uid, title.text, note.text, due!);
              ref.invalidate(goalsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) set(() { busy = false; err = errText(ctx, e); });
            }
          }),
        ])),
      )),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() f) async {
    try {
      await f();
      ref.invalidate(goalsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(plannerRepoProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('goals_title')), actions: const [ProfileButton(), SizedBox(width: 12)]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _add(context, ref), icon: const Icon(Icons.add), label: Text(context.tr('add_goal'))),
      body: AsyncValueView<List<Goal>>(
        value: ref.watch(goalsProvider),
        onRetry: () => ref.invalidate(goalsProvider),
        isEmpty: (l) => l.isEmpty,
        data: (all) {
          final g = groupGoals(all, DateTime.now());
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
            Text(context.tr('reminder_note'), style: Theme.of(context).textTheme.bodySmall),
            for (final k in const ['overdue', 'today', 'upcoming', 'done'])
              if (g[k]!.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(context.tr('g_$k'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: k == 'overdue' ? scheme.error : null))),
                for (final x in g[k]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                      child: Row(children: [
                        Checkbox(value: x.done, onChanged: (v) => _run(context, ref, () => repo.setDone(x.id, v ?? false))),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(x.title, style: TextStyle(fontWeight: FontWeight.w700, decoration: x.done ? TextDecoration.lineThrough : null)),
                          if ((x.description ?? '').isNotEmpty) Text(x.description!, style: Theme.of(context).textTheme.bodySmall),
                          Text('⏰ ${_fmt(x.dueAt)}', style: TextStyle(fontSize: 12, color: k == 'overdue' ? scheme.error : scheme.primary)),
                        ])),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _run(context, ref, () => repo.deleteGoal(x.id))),
                      ]),
                    ),
                  ),
              ],
          ]);
        },
      ),
    );
  }
}
