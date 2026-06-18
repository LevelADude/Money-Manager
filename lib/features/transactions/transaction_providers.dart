import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/transaction_split.dart';
import '../../data/models/transaction_template.dart';
import '../../data/repositories/receipt_storage.dart';
import '../../data/repositories/split_repository.dart';
import '../../data/repositories/template_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../auth/auth_providers.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
  );
});

final splitRepositoryProvider = Provider<SplitRepository>((ref) {
  return SplitRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
  );
});

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
  );
});

/// Live-Liste aller Buchungs-Vorlagen.
final templatesProvider = StreamProvider<List<TransactionTemplate>>((ref) {
  return ref.watch(templateRepositoryProvider).watchAll();
});

/// Live-Liste ALLER Aufteilungen (für Statistik-Aufschlüsselung + Formular).
final allSplitsProvider = StreamProvider<List<TransactionSplit>>((ref) {
  return ref.watch(splitRepositoryProvider).watchAll();
});

/// Aufteilungen gruppiert nach Buchungs-ID.
final splitsByTransactionProvider =
    Provider<Map<String, List<TransactionSplit>>>((ref) {
  final splits = ref.watch(allSplitsProvider).asData?.value ??
      const <TransactionSplit>[];
  final map = <String, List<TransactionSplit>>{};
  for (final s in splits) {
    map.putIfAbsent(s.transactionId, () => []).add(s);
  }
  return map;
});

final receiptStorageProvider = Provider<ReceiptStorage>((ref) {
  return ReceiptStorage(ref.watch(supabaseClientProvider));
});

/// Live-Liste ALLER Buchungen (Basis für Salden/Vermögen/Statistik).
/// Bei Local-First (Phase B) kommt das aus der lokalen DB.
final allTransactionsProvider = StreamProvider<List<AppTransaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAll();
});

/// Buchungen, die ein Konto betreffen (als Quelle ODER Übertragsziel),
/// neueste zuerst.
final accountTransactionsProvider =
    Provider.family<List<AppTransaction>, String>((ref, accountId) {
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final list = txs
      .where((t) => t.accountId == accountId || t.transferAccountId == accountId)
      .toList()
    ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));
  return list;
});

/// Zuletzt verwendete Titel (neueste zuerst, eindeutig) — aus den bereits
/// geladenen Buchungen abgeleitet (kein zusätzlicher Netzwerk-Traffic).
final titleSuggestionsProvider = Provider<List<String>>((ref) {
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final ordered = [...txs]
    ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));
  final seen = <String>{};
  final result = <String>[];
  for (final t in ordered) {
    final title = t.title.trim();
    if (title.isNotEmpty && seen.add(title.toLowerCase())) result.add(title);
  }
  return result;
});

/// Alle bisher vergebenen Tags (alphabetisch, eindeutig) – für Vorschläge
/// im Formular und den Tag-Filter in „Buchungen".
final allTagsProvider = Provider<List<String>>((ref) {
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final seen = <String, String>{}; // kleingeschrieben -> Originalschreibweise
  for (final t in txs) {
    for (final tag in t.tags) {
      final k = tag.trim().toLowerCase();
      if (k.isNotEmpty) seen.putIfAbsent(k, () => tag.trim());
    }
  }
  final result = seen.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
});

/// Map: Titel (kleingeschrieben) -> zuletzt dafür verwendete Kategorie-ID.
/// Für den Kategorie-Vorschlag, wenn ein bekannter Titel gewählt wird.
final titleCategoryProvider = Provider<Map<String, String>>((ref) {
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final ordered = [...txs]
    ..sort((a, b) => a.occurredOn.compareTo(b.occurredOn)); // alt -> neu
  final map = <String, String>{};
  for (final t in ordered) {
    final key = t.title.trim().toLowerCase();
    if (key.isNotEmpty && t.categoryId != null) map[key] = t.categoryId!;
  }
  return map;
});
