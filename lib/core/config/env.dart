/// Supabase sozlamalari. FlutLab'da --dart-define ishlatish qiyin, shuning uchun
/// quyidagi ikki qiymatni to'g'ridan-to'g'ri o'zgartiring (Supabase > Project Settings > API).
/// Faqat Project URL va anon/publishable kalit. service_role / secret kalitni BU YERGA YOZMANG.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://qmrfyvxvmbkokldffpnq.supabase.co');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtcmZ5dnh2bWJrb2tsZGZmcG5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxMjk5MDQsImV4cCI6MjEwNzcwNTkwNH0.eQJQP9qljIZVlLNU5hcIeZ8z-ynHpvgKjRodC5FHg9M');
  static const webUrl = String.fromEnvironment('WEB_URL', defaultValue: 'https://hosilx-full.vercel.app/');

  static String harvestPassportVerificationUrl(String passportId) {
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(passportId)) {
      throw ArgumentError.value(passportId, 'passportId', 'Expected a UUID');
    }
    final base = Uri.parse(supabaseUrl);
    if (base.scheme != 'https' ||
        base.host.isEmpty ||
        base.host == 'localhost' ||
        base.host == '127.0.0.1' ||
        base.userInfo.isNotEmpty ||
        base.host.contains('YOUR_PROJECT')) {
      throw StateError('An HTTPS Supabase project URL is required for passport verification');
    }
    return base.replace(
      path: '/functions/v1/verify-harvest-passport',
      queryParameters: {'token': passportId},
    ).toString();
  }

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && !supabaseAnonKey.startsWith('PASTE');
}
