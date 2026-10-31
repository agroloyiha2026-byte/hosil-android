import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 24),
                      const SizedBox(width: 10),
                      Text(context.tr('about_app'), style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(context.tr('about_app_body')),
                  const SizedBox(height: 8),
                  Text('Hosil X • v1.0.0+1', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(context.tr('language'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'uz', label: Text('UZ')),
              ButtonSegment(value: 'ru', label: Text('RU')),
              ButtonSegment(value: 'en', label: Text('EN')),
            ],
            selected: {settings.locale.languageCode},
            onSelectionChanged: (v) => ctrl.setLocale(v.first),
          ),
          const SizedBox(height: 20),
          Text(context.tr('theme'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.light, label: Text(context.tr('theme_light')), icon: const Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text(context.tr('theme_dark')), icon: const Icon(Icons.dark_mode_outlined)),
              ButtonSegment(value: ThemeMode.system, label: Text(context.tr('theme_system')), icon: const Icon(Icons.brightness_auto_outlined)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (v) => ctrl.setThemeMode(v.first),
          ),
          const SizedBox(height: 20),
          const Card(
            child: ListTile(
              leading: Icon(Icons.security_outlined),
              title: Text('Ma’lumotlar himoyasi'),
              subtitle: Text('Profil, telefon va vaqti kelganda ishlatiladigan ma’lumotlar faqat sizga tegishli bo‘ladi.'),
            ),
          ),
          const SizedBox(height: 10),
          const Card(
            child: ListTile(
              leading: Icon(Icons.support_agent_outlined),
              title: Text('Yordam va aloqa'),
              subtitle: Text('Muammo bo‘lsa, admin yoki yordam chiquvchi orqali bog‘laning.'),
            ),
          ),
        ],
      ),
    );
  }
}
