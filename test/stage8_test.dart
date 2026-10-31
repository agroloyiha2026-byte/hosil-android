import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/models/market_models.dart';
import 'package:hosilx/models/stage8_models.dart';

void main() {
  test('Product.fromMap works without product_images (list query regression)',
      () {
    final p = Product.fromMap({
      'id': '1',
      'title': 'T',
      'category': 'fruit',
      'product_type': 'olma',
      'price': 10,
      'currency': 'UZS',
      'unit': 'kg',
      'quantity': 5,
      'region': 'R',
      'seller_id': 's',
      'created_at': '2026-01-01T00:00:00Z',
      'image_url': null
    });
    expect(p.images, isEmpty);
  });

  test('groupGoals splits overdue/today/upcoming/done', () {
    final now = DateTime(2026, 10, 20, 12);
    Goal g(String id, DateTime d, {bool done = false}) =>
        Goal(id, id, null, d, done);
    final r = groupGoals([
      g('a', DateTime(2026, 10, 19)),
      g('b', DateTime(2026, 10, 20, 18)),
      g('c', DateTime(2026, 10, 25)),
      g('d', DateTime(2026, 10, 1), done: true)
    ], now);
    expect(r['overdue']!.map((e) => e.id), ['a']);
    expect(r['today']!.map((e) => e.id), ['b']);
    expect(r['upcoming']!.map((e) => e.id), ['c']);
    expect(r['done']!.map((e) => e.id), ['d']);
  });

  test('totalsByCurrency keeps currencies apart and skips planned', () {
    final t = totalsByCurrency([
      const FinEntry(
          '1', 'income', 'sales', 1000, 'UZS', false, '2026-01-01', null),
      const FinEntry(
          '2', 'expense', 'seeds', 400, 'UZS', false, '2026-01-01', null),
      const FinEntry(
          '3', 'income', 'sales', 50, 'USD', false, '2026-01-01', null),
      const FinEntry(
          '4', 'expense', 'other', 999, 'UZS', true, '2026-01-01', null),
    ]);
    expect(t['UZS']!.inc, 1000);
    expect(t['UZS']!.exp, 400);
    expect(t['USD']!.inc, 50);
  });

  test('finance categories are separated by entry kind', () {
    expect(financeCategoriesForKind('income'), contains('harvest_sale'));
    expect(financeCategoriesForKind('income'), isNot(contains('seeds')));
    expect(financeCategoriesForKind('expense'), contains('seeds'));
    expect(
        financeCategoriesForKind('expense'), isNot(contains('harvest_sale')));
    expect(() => financeCategoriesForKind('unknown'), throwsArgumentError);
  });
}
