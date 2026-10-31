import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/notifications/reminder_service.dart';
import 'core/notifications/push_service.dart';
import 'core/services/supabase_service.dart';

/// Boshlanishda xato bo'lsa qora ekran o'rniga xato matni ko'rsatiladi (sabab aniqlanishi uchun).
Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await ReminderService.init(); // xato bo'lsa ham ilova ochiladi
    await PushService.initialize(); // Firebase konfiguratsiyasi bo'lmasa, push o'chirilgan holda qoladi.
    String? startupError;
    try {
      await SupabaseService.init().timeout(const Duration(seconds: 10)); // sozlama bo'lmasa o'tkazib yuboradi
    } catch (e, st) {
      startupError = '$e\n\n$st';
    }
    runApp(startupError != null ? _StartupError(startupError) : const ProviderScope(child: HosilApp()));
  }, (error, stack) => debugPrint('Ushlanmagan xato: $error\n$stack'));
}

class _StartupError extends StatelessWidget {
  final String message;
  const _StartupError(this.message);

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text('Hosil X ishga tushmadi:\n\n$message', style: const TextStyle(color: Colors.black, fontSize: 13)),
            ),
          ),
        ),
      );
}
