import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../accounts/account_providers.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';
import '../sharing/account_member_providers.dart';
import 'transaction_providers.dart';

/// Aktiver Personen-Filter (owner_id eines Kontos) oder null = alle Personen.
///
/// Standard: der angemeldete Nutzer selbst – so sieht jede:r zunächst nur die
/// eigenen Finanzen und wechselt bewusst zu „Alle" oder einer anderen Person.
class PersonFilterNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(currentUserIdProvider);
  void set(String? ownerId) => state = ownerId;
}

final personFilterProvider =
    NotifierProvider<PersonFilterNotifier, String?>(PersonFilterNotifier.new);

/// Auswahloptionen: (ownerId, Anzeigename) für alle Konto-Besitzer.
final ownerOptionsProvider = Provider<List<({String id, String name})>>((ref) {
  final accounts =
      ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final names =
      ref.watch(profileNamesProvider).asData?.value ?? const <String, String>{};
  final ids = <String>{
    for (final a in accounts)
      if (a.ownerId != null) a.ownerId!,
  };
  final list = [
    for (final id in ids)
      (id: id, name: names[id]?.isNotEmpty == true ? names[id]! : 'Unbekannt'),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
});

/// Konto-IDs, die zur gewählten Person gehören: eigene Konten ODER geteilte
/// Konten, bei denen die Person Mitglied ist (null = alle).
final _personAccountIdsProvider = Provider<Set<String>?>((ref) {
  final person = ref.watch(personFilterProvider);
  if (person == null) return null;
  final accounts =
      ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final membersByAccount = ref.watch(membersByAccountProvider);
  return {
    for (final a in accounts)
      if (a.ownerId == person ||
          (membersByAccount[a.id]?.contains(person) ?? false))
        a.id,
  };
});

/// Buchungen, gefiltert auf die gewählte Person (eigene + geteilte Konten).
final personFilteredTransactionsProvider =
    Provider<List<AppTransaction>>((ref) {
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final ids = ref.watch(_personAccountIdsProvider);
  if (ids == null) return txs;
  return txs.where((t) => ids.contains(t.accountId)).toList();
});

/// Konten, gefiltert auf die gewählte Person (eigene + geteilte Konten).
final personFilteredAccountsProvider = Provider<List<Account>>((ref) {
  final accounts =
      ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final ids = ref.watch(_personAccountIdsProvider);
  if (ids == null) return accounts;
  return accounts.where((a) => ids.contains(a.id)).toList();
});
