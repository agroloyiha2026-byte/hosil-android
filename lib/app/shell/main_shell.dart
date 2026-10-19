import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../localization/l10n.dart';
import '../theme/app_theme.dart';

/// Pastki navigatsiya (alohida, tuproq rangida): Asosiy, Bozor, AI (o'rtada), Maqsad, Moliya.
class MainShell extends StatelessWidget {
  final Widget child;
  final String location;
  const MainShell({super.key, required this.child, required this.location});

  static const _paths = ['/', '/market', '/assistant', '/goals', '/finance'];

  @override
  Widget build(BuildContext context) {
    final idx = _paths.indexWhere((p) => p == '/' ? location == '/' : location.startsWith(p));
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 68,
          backgroundColor: dark ? AppColors.navDark : AppColors.earth,
          indicatorColor: AppColors.pale,
          iconTheme: WidgetStateProperty.resolveWith((st) =>
              IconThemeData(color: st.contains(WidgetState.selected) ? AppColors.forest : Colors.white70)),
          labelTextStyle: WidgetStateProperty.resolveWith((st) => TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: st.contains(WidgetState.selected) ? Colors.white : Colors.white70)),
        ),
        child: NavigationBar(
          selectedIndex: idx < 0 ? 0 : idx,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => context.go(_paths[i]),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: context.tr('nav_home')),
            NavigationDestination(icon: const Icon(Icons.storefront_outlined), selectedIcon: const Icon(Icons.storefront), label: context.tr('nav_market')),
            NavigationDestination(icon: const Icon(Icons.auto_awesome_outlined), selectedIcon: const Icon(Icons.auto_awesome), label: context.tr('nav_ai')),
            NavigationDestination(icon: const Icon(Icons.flag_outlined), selectedIcon: const Icon(Icons.flag), label: context.tr('nav_goals')),
            NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), selectedIcon: const Icon(Icons.account_balance_wallet), label: context.tr('nav_finance')),
          ],
        ),
      ),
    );
  }
}
