import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/recurring_rule.dart';
import '../../data/repositories/recurring_repository.dart';
import '../auth/auth_providers.dart';
import '../transactions/transaction_providers.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
  );
});

final recurringRulesProvider = StreamProvider<List<RecurringRule>>((ref) {
  return ref.watch(recurringRepositoryProvider).watchRules();
});

/// Läuft einmal pro Session (beim ersten Watch) und erzeugt fällige Buchungen.
final recurringGenerationProvider = FutureProvider<int>((ref) {
  return ref.watch(recurringRepositoryProvider).generateDue();
});

/// Erkannter Abo-/Wiederkehr-Kandidat aus den Buchungen.
class SubscriptionCandidate {
  const SubscriptionCandidate({
    required this.title,
    required this.amountCents,
    required this.accountId,
    required this.type,
    required this.categoryId,
    required this.intervalUnit,
    required this.intervalCount,
    required this.nextDue,
    required this.occurrences,
  });

  final String title;
  final int amountCents;
  final String accountId;
  final TransactionType type;
  final String? categoryId;
  final IntervalUnit intervalUnit;
  final int intervalCount;
  final DateTime nextDue;
  final int occurrences;
}

/// Erkennt regelmäßige Buchungen (gleicher Titel+Betrag+Konto in regelmäßigem
/// Abstand), die noch kein Dauerauftrag sind → Vorschlag zum Anlegen.
final subscriptionSuggestionsProvider = Provider<List<SubscriptionCandidate>>((
  ref,
) {
  final txs =
      ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final rules =
      ref.watch(recurringRulesProvider).asData?.value ??
      const <RecurringRule>[];
  final existing = {
    for (final r in rules)
      '${r.accountId}|${r.title.trim().toLowerCase()}|${r.amountCents}',
  };

  final groups = <String, List<AppTransaction>>{};
  for (final t in txs) {
    if (t.type == TransactionType.transfer) continue;
    if (t.title.trim().isEmpty) continue;
    final key =
        '${t.accountId}|${t.title.trim().toLowerCase()}|${t.amountCents}|${t.type.index}';
    groups.putIfAbsent(key, () => []).add(t);
  }

  final out = <SubscriptionCandidate>[];
  groups.forEach((key, list) {
    if (list.length < 3) return;
    list.sort((a, b) => a.occurredOn.compareTo(b.occurredOn));
    final gaps = <int>[
      for (var i = 1; i < list.length; i++)
        list[i].occurredOn.difference(list[i - 1].occurredOn).inDays,
    ]..sort();
    final med = gaps[gaps.length ~/ 2];
    IntervalUnit? unit;
    var count = 1;
    if (med >= 6 && med <= 8) {
      unit = IntervalUnit.week;
    } else if (med >= 13 && med <= 16) {
      unit = IntervalUnit.week;
      count = 2;
    } else if (med >= 27 && med <= 32) {
      unit = IntervalUnit.month;
    } else if (med >= 88 && med <= 95) {
      unit = IntervalUnit.month;
      count = 3;
    } else if (med >= 360 && med <= 370) {
      unit = IntervalUnit.year;
    }
    if (unit == null) return;

    final first = list.first;
    final exKey =
        '${first.accountId}|${first.title.trim().toLowerCase()}|${first.amountCents}';
    if (existing.contains(exKey)) return;

    out.add(
      SubscriptionCandidate(
        title: first.title,
        amountCents: first.amountCents,
        accountId: first.accountId,
        type: first.type,
        categoryId: first.categoryId,
        intervalUnit: unit,
        intervalCount: count,
        nextDue: advanceDate(list.last.occurredOn, unit, count),
        occurrences: list.length,
      ),
    );
  });
  out.sort((a, b) => b.occurrences.compareTo(a.occurrences));
  return out;
});
