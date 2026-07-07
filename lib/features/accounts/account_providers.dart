import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/account.dart';
import '../../data/models/account_group.dart';
import '../../data/models/app_transaction.dart';
import '../../data/repositories/account_group_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../shared/balances.dart';
import '../archive/archive_providers.dart';
import '../auth/auth_providers.dart';
import '../currency/currency_providers.dart';
import '../sharing/access_grant_providers.dart';
import '../transactions/transaction_providers.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
  );
});

/// Live-Liste aller Konten (inkl. nur-ansehbarer Fremdkonten aus Freigaben).
final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAccounts();
});

/// Konten, die der aktuelle Nutzer verwalten (bebuchen) darf: eigene Konten +
/// Konten von Besitzern mit „manage"-Freigabe. Nur-ansehbare Fremdkonten sind
/// bewusst ausgeschlossen — man kann keine Buchung in einem Konto anlegen, das
/// man nur sehen darf (RLS `can_manage_account` würde das Speichern ohnehin
/// ablehnen). Dient als Quelle für alle Konto-Auswahlen beim Anlegen/Bearbeiten.
final manageableAccountsProvider = Provider<List<Account>>((ref) {
  final accounts =
      ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final owners = ref.watch(manageableOwnersProvider);
  return accounts
      .where((a) => a.ownerId != null && owners.contains(a.ownerId))
      .toList();
});

/// Saldo (Cent) eines Kontos = Anfangssaldo + alle Buchungen (inkl. Überträge).
final accountBalanceProvider = Provider.family<int, String>((ref, accountId) {
  final accounts =
      ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  Account? account;
  for (final a in accounts) {
    if (a.id == accountId) {
      account = a;
      break;
    }
  }
  if (account == null) return 0;
  final txs =
      ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  // Carry-over archivierter Jahre: deren Buchungen sind aus der DB entfernt,
  // ihr Netto-Beitrag steckt im Carry-over, damit der Saldo korrekt bleibt.
  final carryover = ref.watch(archivedCarryoverProvider);
  return accountBalanceCents(account, txs, carryover);
});

final accountGroupRepositoryProvider = Provider<AccountGroupRepository>((ref) {
  return AccountGroupRepository(ref.watch(supabaseClientProvider));
});

/// Eigene Konten-Gruppen (für Custom-Summen).
final accountGroupsProvider = FutureProvider<List<AccountGroup>>((ref) {
  return ref.watch(accountGroupRepositoryProvider).fetchAll();
});

/// Summe (in Hauptwährung) je eigener Konten-Gruppe. Nicht gefundene bzw.
/// gelöschte Konten werden übersprungen.
final accountGroupTotalsProvider =
    Provider<List<({AccountGroup group, int cents})>>((ref) {
      final groups = ref.watch(accountGroupsProvider).asData?.value ?? const [];
      final accounts =
          ref.watch(accountsProvider).asData?.value ?? const <Account>[];
      final txs =
          ref.watch(allTransactionsProvider).asData?.value ??
          const <AppTransaction>[];
      final convert = ref.watch(converterProvider);
      final carryover = ref.watch(archivedCarryoverProvider);
      final byId = {for (final a in accounts) a.id: a};
      return [
        for (final g in groups)
          (
            group: g,
            cents: g.accountIds.fold<int>(0, (s, id) {
              final a = byId[id];
              if (a == null) return s;
              return s +
                  convert(accountBalanceCents(a, txs, carryover), a.currency);
            }),
          ),
      ];
    });

/// Gesamtvermögen (Cent) über alle Konten mit `include_in_net_worth`,
/// optional nur für eine Person (`ownerId`). Verbindlichkeiten sind negativ.
final netWorthProvider = Provider.family<int, String?>((ref, ownerId) {
  final accounts =
      ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final txs =
      ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final convert = ref.watch(converterProvider);
  final carryover = ref.watch(archivedCarryoverProvider);
  var total = 0;
  for (final a in accounts) {
    if (!a.includeInNetWorth || a.archived) continue;
    if (ownerId != null && a.ownerId != ownerId) continue;
    // in Hauptwährung umrechnen
    total += convert(accountBalanceCents(a, txs, carryover), a.currency);
  }
  return total;
});
