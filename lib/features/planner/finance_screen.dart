import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import '../../models/stage8_models.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import 'planner_providers.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  void _add(BuildContext context, WidgetRef ref) {
    final uid = ref.read(sessionProvider).user?.id;
    if (uid == null) return;
    final form = GlobalKey<FormState>();
    final amount = TextEditingController(), note = TextEditingController();
    var kind = 'expense',
        cat = financeExpenseCategories.first,
        cur = 'UZS',
        planned = false,
        busy = false;
    String? err;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: SingleChildScrollView(
                    child: Form(
                        key: form,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(ctx.tr('add_entry'),
                              style: Theme.of(ctx).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                              segments: [
                                ButtonSegment(
                                    value: 'income',
                                    label: Text(ctx.tr('fin_income'))),
                                ButtonSegment(
                                    value: 'expense',
                                    label: Text(ctx.tr('fin_expense')))
                              ],
                              selected: {
                                kind
                              },
                              onSelectionChanged: (v) => set(() {
                                    kind = v.first;
                                    cat = financeCategoriesForKind(kind).first;
                                  })),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                              initialValue: cat,
                              decoration: InputDecoration(
                                  labelText: ctx.tr('fin_category'),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14))),
                              items: [
                                for (final c in financeCategoriesForKind(kind))
                                  DropdownMenuItem(
                                      value: c, child: Text(ctx.tr('fc_$c')))
                              ],
                              onChanged: (v) => set(() => cat =
                                  v ?? financeCategoriesForKind(kind).first)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: AppTextField(
                                    controller: amount,
                                    label: ctx.tr('fin_amount'),
                                    keyboardType: TextInputType.number,
                                    validator: tv(ctx, Validators.positive))),
                            const SizedBox(width: 8),
                            SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                      value: 'UZS', label: Text('UZS')),
                                  ButtonSegment(
                                      value: 'USD', label: Text('USD'))
                                ],
                                selected: {
                                  cur
                                },
                                onSelectionChanged: (v) =>
                                    set(() => cur = v.first)),
                          ]),
                          const SizedBox(height: 12),
                          AppTextField(
                              controller: note, label: ctx.tr('fin_note')),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(ctx.tr('fin_planned')),
                              value: planned,
                              onChanged: (v) => set(() => planned = v)),
                          ErrorText(err),
                          AppButton(
                              label: ctx.tr('save'),
                              loading: busy,
                              onPressed: () async {
                                if (!form.currentState!.validate()) return;
                                set(() {
                                  busy = true;
                                  err = null;
                                });
                                try {
                                  await ref
                                      .read(plannerRepoProvider)
                                      .addEntry(uid, {
                                    'kind': kind,
                                    'category': cat,
                                    'amount': double.parse(amount.text
                                        .replaceAll(' ', '')
                                        .replaceAll(',', '.')),
                                    'currency': cur,
                                    'planned': planned,
                                    'entry_date': DateTime.now()
                                        .toIso8601String()
                                        .substring(0, 10),
                                    'note': note.text.trim().isEmpty
                                        ? null
                                        : note.text.trim()
                                  });
                                  ref.invalidate(financeProvider);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  if (ctx.mounted)
                                    set(() {
                                      busy = false;
                                      err = errText(ctx, e);
                                    });
                                }
                              }),
                        ]))),
              )),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _add(context, ref),
          icon: const Icon(Icons.add),
          label: Text(context.tr('add_entry'))),
      body: AsyncValueView<List<FinEntry>>(
        value: ref.watch(financeProvider),
        onRetry: () => ref.invalidate(financeProvider),
        isEmpty: (l) => l.isEmpty,
        data: (l) {
          final totals = totalsByCurrency(l);
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                for (final e in totals.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(e.key,
                              style: Theme.of(context).textTheme.labelLarge),
                          Text(
                              '${context.tr('fin_income')}: ${fmtNum(e.value.inc)}'),
                          Text(
                              '${context.tr('fin_expense')}: ${fmtNum(e.value.exp)}'),
                          Text(
                              '${context.tr('fin_profit')}: ${fmtNum(e.value.inc - e.value.exp)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: e.value.inc >= e.value.exp
                                      ? scheme.primary
                                      : scheme.error)),
                        ])),
                  ),
                Text(context.tr('fin_currency_note'),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final x in l)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  '${x.kind == 'income' ? '＋' : '－'}${fmtNum(x.amount)} ${x.currency}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: x.kind == 'income'
                                          ? scheme.primary
                                          : scheme.error)),
                              Text(
                                  '${x.entryDate} · ${context.tr('fc_${x.category}')}${x.planned ? ' · ${context.tr('fin_planned')}' : ''}${x.note == null ? '' : ' · ${x.note}'}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ])),
                        IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              try {
                                await ref
                                    .read(plannerRepoProvider)
                                    .deleteEntry(x.id);
                                ref.invalidate(financeProvider);
                              } catch (e) {
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(errText(context, e))));
                              }
                            }),
                      ]),
                    ),
                  ),
              ]);
        },
      ),
    );
  }
}
