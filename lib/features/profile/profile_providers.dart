import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/profile_repository.dart';
import '../auth/auth_providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// Alle sichtbaren Profile (Mitglieder). Einmal geladen, per
/// `ref.invalidate(profilesProvider)` aktualisierbar.
final profilesProvider = FutureProvider<List<Profile>>((ref) async {
  return ref.watch(profileRepositoryProvider).fetchProfiles();
});

/// Map: Profil-ID -> Anzeigename (für Attribution).
final profileNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final profiles = await ref.watch(profilesProvider.future);
  return {for (final p in profiles) p.id: p.displayName};
});

/// Map: Profil-ID -> Basiswährung (zur Deutung der Wechselkurse fremder Konten).
final profileBaseCurrenciesProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final profiles = await ref.watch(profilesProvider.future);
  return {for (final p in profiles) p.id: p.baseCurrency};
});

/// Anzeigename des aktuell angemeldeten Nutzers.
final myDisplayNameProvider = FutureProvider<String>((ref) async {
  return ref.watch(profileRepositoryProvider).fetchMyDisplayName();
});

/// Ist der aktuelle Nutzer Admin?
final isAdminProvider = FutureProvider<bool>((ref) async {
  return ref.watch(profileRepositoryProvider).fetchIsAdmin();
});

/// Hat der aktuelle Nutzer nur Lese-Rechte?
final isReadOnlyProvider = FutureProvider<bool>((ref) async {
  return ref.watch(profileRepositoryProvider).fetchIsReadOnly();
});

/// Ist der aktuelle Nutzer der (geschützte) Besitzer?
final isOwnerProvider = FutureProvider<bool>((ref) async {
  return ref.watch(profileRepositoryProvider).fetchIsOwner();
});
