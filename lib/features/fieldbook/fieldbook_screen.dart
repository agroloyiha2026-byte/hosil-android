import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import 'fieldbook_entry.dart';
import 'fieldbook_providers.dart';

class FieldbookScreen extends ConsumerStatefulWidget {
  const FieldbookScreen({super.key});

  @override
  ConsumerState<FieldbookScreen> createState() => _FieldbookScreenState();
}

class _FieldbookScreenState extends ConsumerState<FieldbookScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final userId = ref.read(sessionProvider).user?.id;
      if (userId != null) ref.read(fieldbookProvider(userId).notifier).sync();
    }
  }

  Future<void> _edit(String userId, {FieldbookEntry? existing}) async {
    final formKey = GlobalKey<FormState>();
    final crop = TextEditingController(text: existing?.cropType ?? '');
    final quantity = TextEditingController(text: existing?.quantity?.toString() ?? '');
    final amount = TextEditingController(text: existing?.amount?.toString() ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    var activity = existing?.activityType ?? 'planting';
    var currency = existing?.currency ?? 'UZS';
    var unit = existing?.unit ?? 'kg';
    var entryDate = existing?.entryDate ?? DateTime.now();
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
                  Text(sheetContext.tr(existing == null ? 'fieldbook_add' : 'fieldbook_edit'),
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: crop,
                    decoration: InputDecoration(labelText: sheetContext.tr('fieldbook_crop')),
                    validator: tv(sheetContext, Validators.required),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: activity,
                    decoration: InputDecoration(labelText: sheetContext.tr('fieldbook_activity')),
                    items: [
                      for (final type in const ['planting', 'seeds', 'irrigation', 'fertilizer', 'pesticide', 'labor', 'fuel', 'harvest', 'income', 'note'])
                        DropdownMenuItem(value: type, child: Text(sheetContext.tr('fieldbook_$type'))),
                    ],
                    onChanged: (value) => setSheetState(() => activity = value ?? 'planting'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: quantity,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: sheetContext.tr('fieldbook_quantity')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: unit,
                          decoration: InputDecoration(labelText: sheetContext.tr('fieldbook_unit')),
                          items: [for (final value in const ['kg', 'litr', 'dona', 'soat', 'm3', 'tonna']) DropdownMenuItem(value: value, child: Text(value))],
                          onChanged: (value) => setSheetState(() => unit = value ?? 'kg'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: sheetContext.tr('fieldbook_amount')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: currency,
                        items: const [
                          DropdownMenuItem(value: 'UZS', child: Text('UZS')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (value) => setSheetState(() => currency = value ?? 'UZS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: note, maxLines: 2, decoration: InputDecoration(labelText: sheetContext.tr('fieldbook_note'))),
                  TextButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: sheetContext,
                        initialDate: entryDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (selected != null && sheetContext.mounted) setSheetState(() => entryDate = selected);
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text('${sheetContext.tr('fieldbook_date')}: ${entryDate.toLocal().toString().substring(0, 10)}'),
                  ),
                  if (error != null) ErrorText(error),
                  const SizedBox(height: 8),
                  AppButton(
                    label: sheetContext.tr('save'),
                    loading: busy,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final parsedQuantity = _optionalNumber(quantity.text);
                      final parsedAmount = _optionalNumber(amount.text);
                      if ((quantity.text.trim().isNotEmpty && parsedQuantity == null) ||
                          (amount.text.trim().isNotEmpty && parsedAmount == null)) {
                        setSheetState(() => error = sheetContext.tr('fieldbook_invalid_number'));
                        return;
                      }
                      setSheetState(() { busy = true; error = null; });
                      final entry = FieldbookEntry(
                        id: existing?.id ?? ref.read(fieldbookRepositoryProvider).createId(),
                        cropType: crop.text.trim(),
                        activityType: activity,
                        entryDate: DateTime(entryDate.year, entryDate.month, entryDate.day),
                        quantity: parsedQuantity,
                        unit: parsedQuantity == null ? null : unit,
                        amount: parsedAmount,
                        currency: currency,
                        note: note.text.trim().isEmpty ? null : note.text.trim(),
                        updatedAt: DateTime.now().toUtc(),
                        synced: false,
                      );
                      try {
                        await ref.read(fieldbookProvider(userId).notifier).save(entry);
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
    crop.dispose();
    quantity.dispose();
    amount.dispose();
    note.dispose();
  }

  double? _optionalNumber(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = double.tryParse(raw.trim().replaceAll(' ', '').replaceAll(',', '.'));
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(sessionProvider.select((state) => state.user?.id));
    if (userId == null) return EmptyView(message: context.tr('fieldbook_login_required'));
    final state = ref.watch(fieldbookProvider(userId));
    final entries = state.entries.where((entry) => !entry.deleted).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('fieldbook_title')),
        actions: [
          IconButton(
            tooltip: context.tr('retry'),
            onPressed: state.syncing ? null : () => ref.read(fieldbookProvider(userId).notifier).sync(),
            icon: state.syncing ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(userId),
        icon: const Icon(Icons.add),
        label: Text(context.tr('fieldbook_add')),
      ),
      body: Column(
        children: [
          if (state.error != null)
            MaterialBanner(
              content: Text(context.tr('fieldbook_sync_error')),
              leading: const Icon(Icons.cloud_off_outlined),
              actions: [
                TextButton(onPressed: () => ref.read(fieldbookProvider(userId).notifier).sync(), child: Text(context.tr('retry'))),
              ],
            ),
          if (state.entries.any((entry) => !entry.synced && !entry.deleted))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(alignment: Alignment.centerLeft, child: Text(context.tr('fieldbook_pending_note'), style: Theme.of(context).textTheme.bodySmall)),
            ),
          Expanded(
            child: state.loading
                ? const LoadingView()
                : entries.isEmpty
                    ? EmptyView(message: context.tr('fieldbook_empty'), icon: Icons.menu_book_outlined)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return AppCard(
                            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Icon(Icons.eco_outlined, color: Theme.of(context).colorScheme.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.cropType, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text('${context.tr('fieldbook_${entry.activityType}')} · ${entry.entryDate.toLocal().toString().substring(0, 10)}',
                                          style: Theme.of(context).textTheme.bodySmall),
                                      if (entry.quantity != null) Text('${fmtNum(entry.quantity!)} ${entry.unit ?? ''}'),
                                      if (entry.amount != null) Text('${fmtNum(entry.amount!)} ${entry.currency}'),
                                      if ((entry.note ?? '').isNotEmpty) Text(entry.note!, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      Text(context.tr(entry.synced ? 'fieldbook_synced' : 'fieldbook_pending'),
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: entry.synced ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiary,
                                              )),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'edit') _edit(userId, existing: entry);
                                    if (action == 'delete') ref.read(fieldbookProvider(userId).notifier).remove(entry);
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(value: 'edit', child: Text(context.tr('edit'))),
                                    PopupMenuItem(value: 'delete', child: Text(context.tr('delete'))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
