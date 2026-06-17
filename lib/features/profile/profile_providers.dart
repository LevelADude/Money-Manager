import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/profile_repository.dart';
import '../auth/auth_providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// Map: Profil-ID -> Anzeigename (für Attribution). Einmal geladen,
/// per `ref.invalidate(profileNamesProvider)` aktualisierbar.
final profileNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final profiles = await ref.watch(profileRepositoryProvider).fetchProfiles();
  return {for (final p in profiles) p.id: p.displayName};
});

/// Anzeigename des aktuell angemeldeten Nutzers.
final myDisplayNameProvider = FutureProvider<String>((ref) async {
  return ref.watch(profileRepositoryProvider).fetchMyDisplayName();
});

/// Ist der aktuelle Nutzer Admin?
final isAdminProvider = FutureProvider<bool>((ref) async {
  return ref.watch(profileRepositoryProvider).fetchIsAdmin();
});
