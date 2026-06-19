import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/access_grant.dart';
import '../../data/repositories/access_grant_repository.dart';
import '../auth/auth_providers.dart';

final accessGrantRepositoryProvider = Provider<AccessGrantRepository>((ref) {
  return AccessGrantRepository(ref.watch(supabaseClientProvider));
});

/// Alle Freigaben, an denen ich beteiligt bin (per RLS gefiltert).
final accessGrantsProvider = FutureProvider<List<AccessGrant>>((ref) async {
  return ref.watch(accessGrantRepositoryProvider).fetchAll();
});

/// Freigaben, die ICH anderen gegeben habe (granteeId -> level).
final grantsIGaveProvider = Provider<Map<String, GrantLevel>>((ref) {
  final me = ref.watch(currentUserIdProvider);
  final all = ref.watch(accessGrantsProvider).asData?.value ?? const [];
  return {
    for (final g in all)
      if (g.ownerId == me) g.granteeId: g.level,
  };
});

/// Freigaben, die ICH bekommen habe (ownerId -> level).
final grantsIReceivedProvider = Provider<Map<String, GrantLevel>>((ref) {
  final me = ref.watch(currentUserIdProvider);
  final all = ref.watch(accessGrantsProvider).asData?.value ?? const [];
  return {
    for (final g in all)
      if (g.granteeId == me) g.ownerId: g.level,
  };
});

/// Besitzer, deren Finanzen ich VERWALTEN darf: ich selbst + manage-Freigaben.
final manageableOwnersProvider = Provider<Set<String>>((ref) {
  final me = ref.watch(currentUserIdProvider);
  final received = ref.watch(grantsIReceivedProvider);
  return {
    ?me,
    for (final e in received.entries)
      if (e.value == GrantLevel.manage) e.key,
  };
});
