import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/app/localization/l10n.dart';
import 'package:hosilx/core/regions.dart';
import 'package:hosilx/core/validation/validators.dart';

void main() {
  test('phone validator accepts +998 and 9 digits only', () {
    expect(Validators.phone('+998 90 123 45 67'), isNull);
    expect(Validators.phone('+998901234567'), isNull);
    expect(Validators.phone('+99890123456'), 'v_phone');
    expect(Validators.phone('901234567'), 'v_phone');
    expect(Validators.phone(''), 'v_phone');
  });

  test('regions: 14 entries and every one has ru/en names', () {
    expect(regionsUz.length, 14);
    for (final r in regionsUz) {
      expect(regionLabel(r, 'ru').isNotEmpty, true);
      expect(regionLabel(r, 'en').isNotEmpty, true);
    }
    expect(regionLabel('Unknown', 'ru'), 'Unknown');
  });

  test('new profile keys exist in all languages', () {
    for (final l in supportedLangs) {
      for (final k in ['phone', 'district', 'farm_name', 'ad_label', 'v_phone']) {
        expect(L10n.all[l]!.containsKey(k), true, reason: '$l/$k');
      }
    }
  });
}
