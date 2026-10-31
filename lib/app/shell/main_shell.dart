import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/header_band.dart';
import '../../features/auth/session_controller.dart';
import '../../features/market/market_providers.dart';
import '../../features/notifications/notification_bridge.dart';
import '../../features/profile/profile_button.dart';
import '../../features/stage5_providers.dart';
import '../../models/market_models.dart';
import '../localization/l10n.dart';
import '../theme/app_theme.dart';

/// Beshta asosiy yo'nalish; markazdagi qo'shish amali sahifa emas.
class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;
  const MainShell({super.key, required this.child, required this.location});

  static const _paths = ['/', '/market', '/assistant', '/finance'];

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(filtersProvider).query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idx = MainShell._paths.indexWhere((p) => p == '/'
        ? widget.location == '/'
        : widget.location.startsWith(p) || (p == '/market' && widget.location.startsWith('/agroapteka')));
    final showCatalogHeader = widget.location == '/' || widget.location.startsWith('/market');
    final dark = Theme.of(context).brightness == Brightness.dark;
    final unread = showCatalogHeader ? ref.watch(unreadCountProvider).valueOrNull ?? 0 : 0;
    final unreadChatsState = showCatalogHeader ? ref.watch(chatUnreadCountProvider) : null;
    final unreadChatsError = unreadChatsState?.hasError ?? false;
    final unreadChats = unreadChatsState?.valueOrNull ?? 0;
    final role = ref.watch(sessionProvider.select((state) => state.profile?.role));
    ref.listen(filtersProvider, (_, next) {
      if (_search.text != next.query) _search.text = next.query;
    });
    return Scaffold(
      body: Column(
        children: [
          if (showCatalogHeader) HeaderBand(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.asset('assets/branding/hosil_x_app_icon.png', width: 28, height: 28, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 6),
                    Text(context.tr('app_name'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        tooltip: context.tr(unreadChatsError ? 'chat_unread_error' : 'inquiries'),
                        color: Colors.white,
                        icon: Badge(
                          isLabelVisible: unreadChatsError || unreadChats > 0,
                          label: Text(unreadChatsError ? '!' : '$unreadChats'),
                          child: const Icon(Icons.chat_bubble_outline, size: 21),
                        ),
                        onPressed: () => context.push('/inquiries'),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Badge(
                        isLabelVisible: unread > 0,
                        label: Text('$unread'),
                        child: IconButton(
                          tooltip: context.tr('notifications'),
                          color: Colors.white,
                          icon: const Icon(Icons.notifications_none, size: 21),
                          onPressed: () => context.push('/notifications'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const SizedBox(width: 40, height: 44, child: Center(child: ProfileButton())),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    ref.read(filtersProvider.notifier).state = ProductFilters(query: value.trim());
                    ref.read(warehouseQueryProvider.notifier).state = value.trim();
                    context.go('/market');
                  },
                  decoration: InputDecoration(
                    hintText: context.tr('search_hint'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    constraints: const BoxConstraints(minHeight: 48),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: dark ? AppColors.navDark : AppColors.deepForest,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, -3))],
          ),
          child: Row(
            children: [
              _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: context.tr('nav_home'),
                  selected: idx == 0, onTap: () => context.go('/')),
              _NavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: context.tr('nav_market'),
                  selected: idx == 1, onTap: () => context.go('/market')),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: context.tr('action_add'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: FloatingActionButton(
                            heroTag: 'main-action-hub',
                            tooltip: context.tr('action_add'),
                            elevation: 2,
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.deepForest,
                            onPressed: () => _showActionHub(context, role),
                            child: const Icon(Icons.add, size: 26),
                          ),
                        ),
                        Text(context.tr('action_add'), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              _NavItem(icon: Icons.auto_awesome_outlined, selectedIcon: Icons.auto_awesome, label: context.tr('nav_ai'),
                  selected: idx == 2, onTap: () => context.go('/assistant')),
              _NavItem(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet,
                  label: context.tr('nav_finance_new'), selected: idx == 3, onTap: () => context.go('/finance')),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionHub(BuildContext context, String? role) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sheetContext.tr('action_add'), style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(sheetContext.tr('action_hub_note'), style: Theme.of(sheetContext).textTheme.bodyMedium),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.sell_outlined,
              title: sheetContext.tr('action_product'),
              enabled: role == 'farmer' || role == 'admin',
              status: role == 'farmer' || role == 'admin'
                  ? sheetContext.tr('action_available')
                  : sheetContext.tr('action_role_needed'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/my-products/new');
              },
            ),
            _ActionTile(
              icon: Icons.auto_awesome_outlined,
              title: sheetContext.tr('nav_ai'),
              status: sheetContext.tr('action_available'),
              enabled: true,
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/assistant');
              },
            ),
            _ActionTile(
              icon: Icons.agriculture,
              title: sheetContext.tr('action_equipment'),
              status: role == 'farmer' || role == 'admin'
                  ? sheetContext.tr('action_available')
                  : sheetContext.tr('action_role_needed'),
              enabled: role == 'farmer' || role == 'admin',
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/services/new/equipment');
              },
            ),
            _ActionTile(
              icon: Icons.warehouse,
              title: sheetContext.tr('action_warehouse'),
              status: role == 'warehouse_owner' || role == 'admin'
                  ? sheetContext.tr('action_available')
                  : sheetContext.tr('action_role_needed'),
              enabled: role == 'warehouse_owner' || role == 'admin',
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/warehouses/new');
              },
            ),
            _ActionTile(
              icon: Icons.local_shipping,
              title: sheetContext.tr('action_logistics'),
              status: role == 'farmer' || role == 'admin'
                  ? sheetContext.tr('action_available')
                  : sheetContext.tr('action_role_needed'),
              enabled: role == 'farmer' || role == 'admin',
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/services/new/logistics');
              },
            ),
            _ActionTile(icon: Icons.menu_book_outlined, title: sheetContext.tr('action_fieldbook'),
                status: role == 'farmer' || role == 'admin'
                    ? sheetContext.tr('action_available')
                    : sheetContext.tr('action_role_needed'),
                enabled: role == 'farmer' || role == 'admin',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/fieldbook');
                }),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? selectedIcon : icon, size: 22, color: selected ? AppColors.gold : Colors.white70),
                  const SizedBox(height: 3),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected ? Colors.white : Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: TextStyle(color: enabled ? null : Theme.of(context).disabledColor)),
        subtitle: Text(status, style: Theme.of(context).textTheme.bodySmall),
        trailing: enabled ? const Icon(Icons.chevron_right) : null,
        enabled: enabled,
        onTap: onTap,
      );
}
