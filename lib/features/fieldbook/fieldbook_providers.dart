import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'fieldbook_entry.dart';
import 'fieldbook_repository.dart';

final fieldbookRepositoryProvider = Provider((ref) => FieldbookRepository());

class FieldbookState {
  final List<FieldbookEntry> entries;
  final bool loading;
  final bool syncing;
  final Object? error;

  const FieldbookState({
    this.entries = const [],
    this.loading = true,
    this.syncing = false,
    this.error,
  });

  FieldbookState copyWith({
    List<FieldbookEntry>? entries,
    bool? loading,
    bool? syncing,
    Object? error,
    bool clearError = false,
  }) =>
      FieldbookState(
        entries: entries ?? this.entries,
        loading: loading ?? this.loading,
        syncing: syncing ?? this.syncing,
        error: clearError ? null : error ?? this.error,
      );
}

class FieldbookController extends StateNotifier<FieldbookState> {
  final FieldbookRepository repository;
  final String userId;
  bool _syncAgain = false;

  FieldbookController(this.repository, this.userId) : super(const FieldbookState()) {
    load();
  }

  Future<void> load() async {
    try {
      final local = await repository.loadLocal(userId);
      if (!mounted) return;
      state = state.copyWith(entries: local, loading: false, clearError: true);
      await sync();
    } catch (error) {
      if (mounted) state = state.copyWith(loading: false, error: error);
    }
  }

  Future<void> save(FieldbookEntry entry) async {
    final entries = [...state.entries.where((item) => item.id != entry.id), entry]
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
    await repository.saveLocal(userId, entries);
    if (mounted) {
      state = state.copyWith(entries: entries, clearError: true);
      await sync();
    }
  }

  Future<void> remove(FieldbookEntry entry) => save(
        entry.copyWith(deleted: true, synced: false, updatedAt: DateTime.now().toUtc()),
      );

  Future<void> sync() async {
    if (state.syncing) {
      _syncAgain = true;
      return;
    }
    state = state.copyWith(syncing: true, clearError: true);
    try {
      do {
        _syncAgain = false;
        final entries = await repository.sync(userId, state.entries);
        final merged = {for (final entry in entries) entry.id: entry};
        for (final current in state.entries.where((entry) => !entry.synced)) {
          final remote = merged[current.id];
          if (remote == null || current.updatedAt.isAfter(remote.updatedAt)) merged[current.id] = current;
        }
        final reconciled = merged.values.toList()
          ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
        await repository.saveLocal(userId, reconciled);
        if (mounted) state = state.copyWith(entries: reconciled, clearError: true);
      } while (_syncAgain && mounted);
      if (mounted) state = state.copyWith(syncing: false);
    } catch (error) {
      if (mounted) state = state.copyWith(syncing: false, error: error);
    }
  }
}

final fieldbookProvider = StateNotifierProvider.autoDispose.family<FieldbookController, FieldbookState, String>(
  (ref, userId) => FieldbookController(ref.read(fieldbookRepositoryProvider), userId),
);
