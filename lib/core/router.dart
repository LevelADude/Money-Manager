import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/login_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/ledgers/ledger_detail_screen.dart';
import '../features/ledgers/ledgers_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/transactions/transaction_form_screen.dart';

/// go_router mit Auth-abhängiger Umleitung.
///
/// `refreshListenable` wird bei jeder Auth-Änderung benachrichtigt, wodurch
/// `redirect` neu ausgewertet wird (Login/Logout leitet automatisch um).
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
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const LedgersScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/ledger/:id',
        builder: (context, state) =>
            LedgerDetailScreen(ledgerId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) =>
                TransactionFormScreen(ledgerId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'edit/:txId',
            builder: (context, state) => TransactionFormScreen(
              ledgerId: state.pathParameters['id']!,
              transactionId: state.pathParameters['txId'],
            ),
          ),
          GoRoute(
            path: 'categories',
            builder: (context, state) =>
                CategoriesScreen(ledgerId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});
