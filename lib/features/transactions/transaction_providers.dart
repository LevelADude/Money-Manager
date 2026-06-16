import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../auth/auth_providers.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(supabaseClientProvider));
});

/// Live-Liste der Buchungen eines Buchs (per ledgerId).
final transactionsProvider =
    StreamProvider.family<List<AppTransaction>, String>((ref, ledgerId) {
  return ref.watch(transactionRepositoryProvider).watchTransactions(ledgerId);
});
