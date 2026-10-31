import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/widgets.dart';
import '../features/auth/login_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/market/market_screen.dart';
import '../features/market/product_detail_screen.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/inquiries/inquiries_screen.dart';
import '../features/inquiries/chat_thread_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/warehouses/warehouse_detail_screen.dart';
import '../features/warehouses/warehouse_listing_form_screen.dart';
import '../features/warehouses/warehouses_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/admin_moderation_screen.dart';
import '../features/admin/admin_users_screen.dart';
import '../features/products/my_products_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/admin/admin_categories_screen.dart';
import '../features/admin/admin_media_screen.dart';
import '../features/admin/admin_reports_screen.dart';
import '../features/admin/admin_settings_screen.dart';
import '../features/admin/admin_services_screen.dart';
import '../features/admin/admin_seller_verification_screen.dart';
import '../features/planner/finance_screen.dart';
import '../features/planner/goals_screen.dart';
import '../features/planner/savings_goals_screen.dart';
import '../features/planner/universal_goals_screen.dart';
import 'shell/main_shell.dart';
import '../features/auth/profile_setup_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/reset_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/auth/welcome_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/calculators/agro_calculators_screen.dart';
import '../features/fieldbook/fieldbook_screen.dart';
import '../features/weather/agro_weather_screen.dart';
import '../features/services/service_listings_screen.dart';
import '../features/services/service_listing_form_screen.dart';
import '../features/passports/passports_screen.dart';
import '../features/agroapteka/agroapteka_screens.dart';

const _publicRoutes = ['/welcome', '/login', '/register', '/reset'];

/// Yo'naltirish qoidalari: sessiya yo'q -> kirish sahifalari; profil to'ldirilmagan -> /setup;
/// aks holda -> asosiy ekran. Bu faqat qulaylik; haqiqiy xavfsizlik Supabase RLS da.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      if (s.loading) return loc == '/splash' ? null : '/splash';
      if (s.user == null) return _publicRoutes.contains(loc) ? null : '/welcome';
      final p = s.profile;
      if (p != null && !p.onboarded) return loc == '/setup' ? null : '/setup';
      if (_publicRoutes.contains(loc) || loc == '/splash' || (loc == '/setup' && p?.onboarded == true)) return '/';
      if (loc.startsWith('/admin') && p?.isAdmin != true) return '/'; // qulaylik; haqiqiy himoya serverda
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: LoadingView())),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/reset', builder: (_, __) => const ResetScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const ProfileSetupScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/market', builder: (_, __) => const MarketScreen()),
          GoRoute(path: '/agroapteka', builder: (_, __) => const AgroaptekaScreen()),
          GoRoute(path: '/agroapteka/my-inquiries', builder: (_, __) => const AgroCustomerInquiriesScreen()),
          GoRoute(
            path: '/assistant',
            builder: (_, state) => AssistantScreen(mode: state.uri.queryParameters['mode'] ?? 'assistant'),
          ),
          GoRoute(path: '/finance', builder: (_, __) => const FinanceScreen()),
        ],
      ),
      GoRoute(path: '/goals', builder: (_, __) => const UniversalGoalsScreen()),
      GoRoute(path: '/goals/savings', builder: (_, __) => const SavingsGoalsScreen()),
      GoRoute(path: '/tasks', builder: (_, __) => const GoalsScreen()),
      GoRoute(path: '/warehouses', builder: (_, __) => const WarehousesScreen()),
      GoRoute(path: '/warehouses/new', builder: (_, __) => const WarehouseListingFormScreen()),
      GoRoute(path: '/warehouse/:id', builder: (_, state) => WarehouseDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/inquiries', builder: (_, __) => const InquiriesScreen()),
      GoRoute(path: '/chat/:id', builder: (_, state) => ChatThreadScreen(inquiryId: state.pathParameters['id']!)),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
      GoRoute(path: '/my-products', builder: (_, __) => const MyProductsScreen()),
      GoRoute(path: '/my-products/new', builder: (_, __) => const ProductFormScreen()),
      GoRoute(path: '/my-products/edit/:id', builder: (_, state) => ProductFormScreen(id: state.pathParameters['id'])),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/categories', builder: (_, __) => const AdminCategoriesScreen()),
      GoRoute(path: '/admin/banners', builder: (_, __) => const AdminMediaScreen(kind: 'banners')),
      GoRoute(path: '/admin/ads', builder: (_, __) => const AdminMediaScreen(kind: 'ads')),
      GoRoute(path: '/admin/settings', builder: (_, __) => const AdminSettingsScreen()),
      GoRoute(path: '/admin/reports', builder: (_, __) => const AdminReportsScreen()),
      GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
      GoRoute(path: '/admin/moderation', builder: (_, __) => const AdminModerationScreen()),
      GoRoute(path: '/admin/services', builder: (_, __) => const AdminServicesScreen()),
      GoRoute(path: '/admin/sellers', builder: (_, __) => const AdminSellerVerificationScreen()),
      GoRoute(path: '/product/:id', builder: (_, state) => ProductDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/agroapteka/store/:id', builder: (_, state) => AgroStoreScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/agroapteka/chat/:id', builder: (_, state) => AgroInquiryChatScreen(inquiryId: state.pathParameters['id']!)),
      GoRoute(path: '/agroapteka/manage', builder: (_, __) => const AgroOwnerScreen()),
      GoRoute(path: '/agroapteka/manage/profile', builder: (_, __) => const AgroStoreFormScreen()),
      GoRoute(path: '/agroapteka/manage/product/new', builder: (_, __) => const AgroProductFormScreen()),
      GoRoute(path: '/agroapteka/manage/product/:id/edit', builder: (_, state) => AgroProductFormScreen(id: state.pathParameters['id'])),
      GoRoute(path: '/admin/agroapteka', builder: (_, __) => const AgroAdminScreen()),
      GoRoute(path: '/admin/agroapteka/categories', builder: (_, __) => const AgroCategoryAdminScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/calculators', builder: (_, __) => const AgroCalculatorsScreen()),
      GoRoute(path: '/fieldbook', builder: (_, __) => const FieldbookScreen()),
      GoRoute(path: '/passports', builder: (_, __) => const PassportsScreen()),
      GoRoute(path: '/passports/:id', builder: (_, state) => PassportsScreen(passportId: state.pathParameters['id']!)),
      GoRoute(path: '/weather', builder: (_, __) => const AgroWeatherScreen()),
      GoRoute(path: '/services/:type', builder: (_, state) => ServiceListingsScreen(type: state.pathParameters['type']!)),
      GoRoute(path: '/service/:type/:id', builder: (_, state) => ServiceListingDetailScreen(
        type: state.pathParameters['type']!, id: state.pathParameters['id']!,
      )),
      GoRoute(path: '/services/new/:type', builder: (_, state) => ServiceListingFormScreen(type: state.pathParameters['type']!)),
    ],
  );
});
