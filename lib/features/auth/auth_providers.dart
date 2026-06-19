import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';

/// Der globale Supabase-Client.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Stream der Auth-Zustandsänderungen (Login/Logout/Token-Refresh).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// User-ID des aktuell angemeldeten Nutzers (oder null). Reagiert auf
/// Login/Logout, damit die Standard-Ansicht „nur ich" immer stimmt.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});
