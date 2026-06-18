import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/accounts/account_detail_screen.dart';
import '../features/accounts/account_form_screen.dart';
import '../features/accounts/accounts_reorder_screen.dart';
import '../features/accounts/accounts_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/budgets/budgets_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/export/export_screen.dart';
import '../features/more/more_screen.dart';
import '../features/planning/planning_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/recurring/recurring_form_screen.dart';
import '../features/recurring/recurring_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/statistics/statistics_screen.dart';
import '../features/transactions/all_transactions_screen.dart';
import '../features/transactions/transaction_form_screen.dart';
import 'main_scaffold.dart';

/// go_router mit persistenter Menüleiste (StatefulShellRoute) + Auth-Redirect.
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AuthState?>(null);
  final sub = Supabase.instance.client.auth.onAuthStateChange
      .listen((state) => authNotifier.value = state);
  ref.onDispose(() {
    sub.cancel();
    authNotifier.dispose();
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainScaffold(shell: shell),
        branches: [
          // ---- Konten ----
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (c, s) => const AccountsScreen(),
                routes: [
                  GoRoute(
                    path: 'account/reorder',
                    builder: (c, s) => const AccountsReorderScreen(),
                  ),
                  GoRoute(
                    path: 'account/new',
                    builder: (c, s) => const AccountFormScreen(),
                  ),
                  GoRoute(
                    path: 'account/:id',
                    builder: (c, s) =>
                        AccountDetailScreen(accountId: s.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (c, s) => AccountFormScreen(
                            accountId: s.pathParameters['id']),
                      ),
                      GoRoute(
                        path: 'tx/new',
                        builder: (c, s) => TransactionFormScreen(
                            accountId: s.pathParameters['id']),
                      ),
                      GoRoute(
                        path: 'tx/:txId',
                        builder: (c, s) => TransactionFormScreen(
                          accountId: s.pathParameters['id'],
                          transactionId: s.pathParameters['txId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // ---- Buchungen ----
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (c, s) => const AllTransactionsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const TransactionFormScreen(),
                  ),
                  GoRoute(
                    path: ':txId',
                    builder: (c, s) => TransactionFormScreen(
                        transactionId: s.pathParameters['txId']),
                  ),
                ],
              ),
            ],
          ),
          // ---- Statistik ----
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/statistics',
                builder: (c, s) => const StatisticsScreen(),
              ),
            ],
          ),
          // ---- Mehr ----
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (c, s) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'budgets',
                    builder: (c, s) => const BudgetsScreen(),
                  ),
                  GoRoute(
                    path: 'planning',
                    builder: (c, s) => const PlanningScreen(),
                  ),
                  GoRoute(
                    path: 'recurring',
                    builder: (c, s) => const RecurringScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (c, s) => const RecurringFormScreen(),
                      ),
                      GoRoute(
                        path: ':id/edit',
                        builder: (c, s) => RecurringFormScreen(
                            ruleId: s.pathParameters['id']),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'categories',
                    builder: (c, s) => const CategoriesScreen(),
                  ),
                  GoRoute(
                    path: 'export',
                    builder: (c, s) => const ExportScreen(),
                  ),
                  GoRoute(
                    path: 'search',
                    builder: (c, s) => const SearchScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (c, s) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    builder: (c, s) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'admin',
                    builder: (c, s) => const AdminScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
