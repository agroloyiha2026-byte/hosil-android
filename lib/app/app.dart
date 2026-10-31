import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/notifications/notification_bridge.dart';
import '../features/notifications/push_registration_bridge.dart';
import '../features/planner/planner_providers.dart';
import '../features/settings/settings_controller.dart';
import 'localization/l10n.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class HosilApp extends ConsumerWidget {
  const HosilApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    ref.watch(realtimeBridgeProvider); // yangi bildirishnomalarni telefonda ko'rsatadi
    ref.watch(pushRegistrationBridgeProvider);
    ref.listen(goalsProvider, (_, __) {}); // maqsad eslatmalari ilova ochilishi bilan rejalashtiriladi
    return MaterialApp.router(
      title: 'Hosil X',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: supportedLangs.map(Locale.new).toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
