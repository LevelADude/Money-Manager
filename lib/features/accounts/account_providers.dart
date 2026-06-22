import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/repositories/account_repository.dart';
import '../archive/archive_providers.dart';
import '../auth/auth_providers.dart';
import '../currency/currency_providers.dart';
import '../transactions/transaction_providers.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
  );
});

/// Live-Liste aller Konten.
final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAccounts();
});

/// Saldo (Cent) eines Kontos = Anfangssaldo + alle Buchungen (inkl. Überträge).
final accountBalanceProvider = Provider.family<int, String>((ref, accountId) {
  final accounts = ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  Account? account;
  for (final a in accounts) {
    if (a.id == accountId) {
      account = a;
      break;
    }
  }
  if (account == null) return 0;
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  // Carry-over archivierter Jahre: deren Buchungen sind aus der DB entfernt,
  // ihr Netto-Beitrag steckt im Carry-over, damit der Saldo korrekt bleibt.
  final carryover = ref.watch(archivedCarryoverProvider);
  var sum = account.openingBalanceCents + (carryover[accountId] ?? 0);
  for (final t in txs) {
    sum += t.signedCentsFor(accountId);
  }
  return sum;
});

/// Gesamtvermögen (Cent) über alle Konten mit `include_in_net_worth`,
/// optional nur für eine Person (`ownerId`). Verbindlichkeiten sind negativ.
final netWorthProvider = Provider.family<int, String?>((ref, ownerId) {
  final accounts = ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final convert = ref.watch(converterProvider);
  final carryover = ref.watch(archivedCarryoverProvider);
  var total = 0;
  for (final a in accounts) {
    if (!a.includeInNetWorth || a.archived) continue;
    if (ownerId != null && a.ownerId != ownerId) continue;
    var sum = a.openingBalanceCents + (carryover[a.id] ?? 0);
    for (final t in txs) {
      sum += t.signedCentsFor(a.id);
    }
    total += convert(sum, a.currency); // in Hauptwährung umrechnen
  }
  return total;
});
