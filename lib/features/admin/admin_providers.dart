import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/admin_repository.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
});

final allowedEmailsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchAllowedEmails();
});

final allProfilesProvider = FutureProvider<List<Profile>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchProfiles();
});

/// E-Mail je Nutzer-Id, nur für Admins (Nutzer-Id -> E-Mail).
final userEmailsProvider = FutureProvider<Map<String, String>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchUserEmails();
});

/// Aktuelle Speichernutzung (DB + Datei-Speicher) in Bytes.
final storageStatsProvider = FutureProvider<({int dbBytes, int storageBytes})>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).fetchStorageStats();
});
