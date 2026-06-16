import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ledger.dart';
import '../../data/repositories/ledger_repository.dart';
import '../auth/auth_providers.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  return LedgerRepository(ref.watch(supabaseClientProvider));
});

/// Live-Liste aller Bücher.
final ledgersProvider = StreamProvider<List<Ledger>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchLedgers();
});
