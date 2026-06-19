import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/accounts/account_providers.dart';
import '../features/categories/category_providers.dart';
import '../features/profile/profile_providers.dart';
import '../features/sharing/access_grant_providers.dart';
import '../features/transactions/transaction_providers.dart';

/// Lädt alle zentralen Daten neu: Realtime-Streams re-subscriben (frischer
/// DB-Snapshot) und einmalig geladene FutureProvider neu abfragen.
///
/// Wird vom Aktualisieren-Knopf, von Pull-to-Refresh und beim Wiederöffnen der
/// App (Lifecycle „resumed") genutzt – so sieht man immer die neuesten Daten,
/// auch wenn die Realtime-Verbindung beim Start kurz hängt.
void refreshAllData(WidgetRef ref) {
  ref.invalidate(accountsProvider);
  ref.invalidate(allTransactionsProvider);
  ref.invalidate(allSplitsProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(categoryRulesProvider);
  ref.invalidate(accessGrantsProvider);
  ref.invalidate(profileNamesProvider);
}
