import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../accounts/account_providers.dart';
import '../profile/profile_providers.dart';
import 'transaction_providers.dart';

/// Aktiver Personen-Filter (owner_id eines Kontos) oder null = alle.
class PersonFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
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

/// Buchungen, gefiltert auf die gewählte Person (über den Konto-Besitzer).
final personFilteredTransactionsProvider =
    Provider<List<AppTransaction>>((ref) {
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final person = ref.watch(personFilterProvider);
  if (person == null) return txs;
  final accounts =
      ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final ownerOf = {for (final a in accounts) a.id: a.ownerId};
  return txs.where((t) => ownerOf[t.accountId] == person).toList();
});

/// Konten, gefiltert auf die gewählte Person.
final personFilteredAccountsProvider = Provider<List<Account>>((ref) {
  final accounts =
      ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final person = ref.watch(personFilterProvider);
  if (person == null) return accounts;
  return accounts.where((a) => a.ownerId == person).toList();
});
