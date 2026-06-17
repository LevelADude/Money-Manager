import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/recurring_rule.dart';
import '../../data/repositories/recurring_repository.dart';
import '../auth/auth_providers.dart';

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
