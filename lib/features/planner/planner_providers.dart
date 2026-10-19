import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notifications/reminder_service.dart';
import '../../models/stage8_models.dart';
import '../auth/session_controller.dart';
import 'planner_repository.dart';

final plannerRepoProvider = Provider((ref) => PlannerRepository());

final goalsProvider = FutureProvider.autoDispose<List<Goal>>((ref) async {
  final uid = ref.watch(sessionProvider.select((s) => s.user?.id));
  if (uid == null) return const <Goal>[];
  final goals = await ref.read(plannerRepoProvider).goals(uid);
  await ReminderService.sync(goals); // telefon eslatmalarini yangilaydi
  return goals;
});

final financeProvider = FutureProvider.autoDispose<List<FinEntry>>((ref) {
  final uid = ref.watch(sessionProvider.select((s) => s.user?.id));
  return uid == null ? Future.value(const <FinEntry>[]) : ref.read(plannerRepoProvider).entries(uid);
});
