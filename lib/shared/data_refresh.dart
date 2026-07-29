import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/accounts/account_providers.dart';
import '../features/categories/category_providers.dart';
import '../features/profile/profile_providers.dart';
import '../features/sharing/access_grant_providers.dart';
import '../features/sharing/account_member_providers.dart';
import '../features/transactions/transaction_providers.dart';

/// Lädt alle zentralen Daten neu: Realtime-Streams re-subscriben (frischer
/// DB-Snapshot) und einmalig geladene FutureProvider neu abfragen.
///
/// Wird vom Aktualisieren-Knopf, von Pull-to-Refresh und beim Wiederöffnen der
/// App (Lifecycle „resumed") genutzt – so sieht man immer die neuesten Daten,
/// auch wenn die Realtime-Verbindung beim Start kurz hängt.
///
/// WICHTIG: Das ist ein *stiller* Refresh im Hintergrund. Die Oberfläche zeigt
/// währenddessen weiter die bisherigen Daten und tauscht nur das aus, was sich
/// wirklich geändert hat – kein Spinner, kein Zurückspringen von Formularen.
/// Dafür müssen Provider-Werte immer über `AsyncValue.value` gelesen werden
/// (behält den letzten Stand beim Neuladen) und NIE über `asData?.value`
/// (wird beim Neuladen kurz `null` → die ganze Seite blitzt leer auf).
void refreshAllData(WidgetRef ref) {
  ref.invalidate(accountsProvider);
  ref.invalidate(accountGroupsProvider);
  ref.invalidate(allTransactionsProvider);
  ref.invalidate(allSplitsProvider);
  ref.invalidate(categoriesRawProvider);
  ref.invalidate(categoryPrefsProvider);
  ref.invalidate(categoryRulesProvider);
  ref.invalidate(accessGrantsProvider);
  ref.invalidate(accountMembersProvider);
  ref.invalidate(profileNamesProvider);
}
