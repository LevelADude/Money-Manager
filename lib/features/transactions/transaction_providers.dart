import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../auth/auth_providers.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(supabaseClientProvider));
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
