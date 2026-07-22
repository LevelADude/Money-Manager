import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account_member.dart';
import '../../data/repositories/account_member_repository.dart';
import '../auth/auth_providers.dart';

final accountMemberRepositoryProvider = Provider<AccountMemberRepository>((
  ref,
) {
  return AccountMemberRepository(ref.watch(supabaseClientProvider));
});

/// Alle für mich sichtbaren Mitgliedschaften (geteilte Konten).
final accountMembersProvider = FutureProvider<List<AccountMember>>((ref) async {
  return ref.watch(accountMemberRepositoryProvider).fetchAll();
});

/// Konto-ID -> Menge der Mitglieder-User-IDs (ohne Besitzer).
final membersByAccountProvider = Provider<Map<String, Set<String>>>((ref) {
  final all = ref.watch(accountMembersProvider).value ?? const [];
  final map = <String, Set<String>>{};
  for (final m in all) {
    map.putIfAbsent(m.accountId, () => <String>{}).add(m.userId);
  }
  return map;
});
