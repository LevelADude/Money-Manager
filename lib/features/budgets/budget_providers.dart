import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/budget.dart';
import '../../data/repositories/budget_repository.dart';
import '../auth/auth_providers.dart';
import '../currency/currency_providers.dart';
import '../settings/settings_providers.dart';
import '../transactions/transaction_providers.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
  );
});

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchBudgets();
});

/// Map: Kategorie-ID -> Budget (für schnellen Zugriff inkl. Budget-ID).
final budgetsByCategoryProvider = Provider<Map<String, Budget>>((ref) {
  final budgets = ref.watch(budgetsProvider).asData?.value ?? const <Budget>[];
  return {for (final b in budgets) b.categoryId: b};
});

/// Ausgaben des laufenden Monats je Kategorie (Cent). Split-bewusst: bei
/// aufgeteilten Buchungen zählen die einzelnen Split-Beträge je Kategorie.
final monthlySpentByCategoryProvider = Provider<Map<String, int>>((ref) {
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final splitsByTx = ref.watch(splitsByTransactionProvider);
  final convert = ref.watch(converterProvider);
  final curOf = ref.watch(accountCurrencyProvider);
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final now = DateTime.now();
  final map = <String, int>{};
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    if (t.occurredOn.year != now.year || t.occurredOn.month != now.month) {
      continue;
    }
    final code = curOf[t.accountId] ?? base;
    final splits = splitsByTx[t.id];
    if (splits != null && splits.isNotEmpty) {
      for (final s in splits) {
        if (s.categoryId == null) continue;
        final v = convert(s.amountCents, code);
        map.update(s.categoryId!, (x) => x + v, ifAbsent: () => v);
      }
    } else {
      final cat = t.categoryId;
      if (cat == null) continue;
      final v = convert(t.amountCents, code);
      map.update(cat, (x) => x + v, ifAbsent: () => v);
    }
  }
  return map;
});
