import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/app/localization/l10n.dart';

void main() {
  test('uz, ru, en have exactly the same keys', () {
    final uz = L10n.all['uz']!.keys.toSet();
    expect(L10n.all['ru']!.keys.toSet(), uz);
    expect(L10n.all['en']!.keys.toSet(), uz);
  });

  test('no empty translations', () {
    for (final lang in supportedLangs) {
      L10n.all[lang]!.forEach((k, v) => expect(v.trim().isNotEmpty, true, reason: '$lang/$k'));
    }
  });

  test('unknown key falls back to the key itself', () {
    expect(L10n.tr('en', 'does_not_exist'), 'does_not_exist');
  });

  test('quick service and unavailable-service copy are translated', () {
    for (final lang in supportedLangs) {
      expect(L10n.tr(lang, 'quick_services'), isNot('quick_services'));
      expect(L10n.tr(lang, 'service_not_connected'), isNot('service_not_connected'));
      expect(L10n.tr(lang, 'banner_fallback_title'), isNot('banner_fallback_title'));
    }
  });

  test('passport, phone, seller verification, and escrow copy is translated', () {
    for (final lang in supportedLangs) {
      for (final key in const [
        'passport_title',
        'verify_phone',
        'phone_otp_sent',
        'seller_verified',
        'seller_verification_empty',
        'escrow_unavailable',
      ]) {
        expect(L10n.tr(lang, key), isNot(key), reason: '$lang/$key');
      }
    }
  });

  test('Agroapteka actions and moderation copy is translated', () {
    for (final lang in supportedLangs) {
      for (final key in const [
        'agroapteka',
        'agro_owner_panel',
        'agro_payment_unavailable',
        'agro_report',
        'agro_categories_manage',
        'agro_not_enough_stock',
      ]) {
        expect(L10n.tr(lang, key), isNot(key), reason: '$lang/$key');
      }
    }
  });

  test('universal goals, banner destinations, and passport links are translated', () {
    for (final lang in supportedLangs) {
      for (final key in const [
        'goal_cat_farming',
        'goal_progress_tasks',
        'goal_status_cancelled',
        'goal_history',
        'banner_target_agroapteka',
        'banner_target_warehouse',
        'ad_no_link',
        'passport_copy_link',
      ]) {
        expect(L10n.tr(lang, key), isNot(key), reason: '$lang/$key');
      }
    }
  });
}
