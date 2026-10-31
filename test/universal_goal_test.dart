import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/features/planner/universal_goal.dart';

UniversalGoal goal({
  String mode = 'metric',
  double? target = 10,
  double current = 3,
  double manual = 0,
}) =>
    UniversalGoal(
      id: 'goal',
      userId: 'owner',
      title: 'Goal',
      category: 'farming',
      startDate: DateTime(2026),
      priority: 'medium',
      status: 'active',
      progressMode: mode,
      targetValue: target,
      currentValue: current,
      manualProgress: manual,
    );

void main() {
  test('metric progress uses its actual measurement and is capped', () {
    expect(goal().progress(), .3);
    expect(goal(current: 12).progress(), 1);
    expect(goal(target: 0).progress(), isNull);
    expect(goal(target: null).progress(), isNull);
  });

  test('task and manual progress use their own values', () {
    expect(goal(mode: 'tasks').progress(taskCount: 4, completedTasks: 1), .25);
    expect(goal(mode: 'tasks').progress(), isNull);
    expect(goal(mode: 'manual', manual: 65).progress(), .65);
    expect(goal(mode: 'manual', manual: 140).progress(), 1);
  });
}
