
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';

class SupabaseService {
  static bool ready = false;

  static Future<void> init() async {
    // Supabase allaqachon ishga tushirilgan bo‘lsa, qayta boshlamaymiz.
    if (ready) return;

    // URL yoki publishable key sozlanmagan bo‘lsa, to‘xtaymiz.
    if (!Env.isConfigured) return;

    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );

    ready = true;
  }

  /// Faqat init() muvaffaqiyatli bajarilgandan keyin chaqiring.
  static SupabaseClient get client {
    if (!ready) {
      throw StateError(
        'Supabase hali ishga tushmagan. '
        'Avval SupabaseService.init() ni chaqiring.',
      );
    }

    return Supabase.instance.client;
  }
}
