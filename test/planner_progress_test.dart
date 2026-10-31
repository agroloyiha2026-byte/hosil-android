import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/features/planner/planner_repository.dart';
import 'package:hosilx/models/stage8_models.dart';

void main() {
  test('goal parsing supports status-based completion and metadata', () {
    final goal = Goal.fromMap({
      'id': 'g1',
      'title': '10 tonna pomidor',
      'description': 'Mavsumlik hosil maqsadi',
      'due_at': '2026-11-15T10:00:00Z',
      'status': 'in_progress',
      'category': 'harvest',
      'priority': 'high',
      'goal_id': 'goal-1',
      'done': false,
    });

    expect(goal.status, 'in_progress');
    expect(goal.category, 'harvest');
    expect(goal.priority, 'high');
    expect(goal.goalId, 'goal-1');
    expect(goal.done, false);
  });

  test('financial goal progress is calculated safely against target values', () {
    final goal = SavingsGoal(
      id: 's1',
      title: 'Traktor uchun jamg\'arma',
      currency: 'UZS',
      targetAmount: 20000000,
      savedAmount: 10000000,
      category: 'purchase',
      status: 'active',
    );

    expect(goal.progressPercent, closeTo(50.0, 0.0001));
    expect(goal.isCompleted, false);
    expect(() => SavingsGoal(
      id: 'bad',
      title: 'Bad',
      currency: 'UZS',
      targetAmount: 0,
      savedAmount: 0,
    ).progressPercent, throwsArgumentError);
  });
}
