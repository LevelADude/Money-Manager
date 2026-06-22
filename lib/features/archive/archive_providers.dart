import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/archive_config_status.dart';
import '../../data/models/archived_year.dart';
import '../../data/repositories/archive_repository.dart';
import '../auth/auth_providers.dart';
import '../transactions/transaction_providers.dart';

final archiveRepositoryProvider = Provider<ArchiveRepository>((ref) {
  return ArchiveRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
    ref.watch(receiptStorageProvider),
  );
});

/// Status der Archiv-Repo-Verbindung (eingerichtet? welches Repo?).
final archiveConfigStatusProvider =
    FutureProvider<ArchiveConfigStatus>((ref) {
  return ref.watch(archiveRepositoryProvider).archiveConfigStatus();
});

/// Live-Liste der archivierten Jahre (Marker + Carry-over).
final archivedYearsProvider = StreamProvider<List<ArchivedYear>>((ref) {
  return ref.watch(archiveRepositoryProvider).watchArchivedYears();
});

/// Carry-over je Konto über ALLE archivierten Jahre (Cent) – wird zum Saldo
/// addiert, damit die Kontostände nach dem Archivieren korrekt bleiben.
final archivedCarryoverProvider = Provider<Map<String, int>>((ref) {
  final years =
      ref.watch(archivedYearsProvider).asData?.value ?? const <ArchivedYear>[];
  final map = <String, int>{};
  for (final y in years) {
    y.carryoverByAccount.forEach((acc, cents) {
      map[acc] = (map[acc] ?? 0) + cents;
    });
  }
  return map;
});

/// Menge der bereits archivierten Jahre (für die Jahres-Auswahl in der UI).
final archivedYearSetProvider = Provider<Set<int>>((ref) {
  final years =
      ref.watch(archivedYearsProvider).asData?.value ?? const <ArchivedYear>[];
  return {for (final y in years) y.year};
});

/// Lädt die Buchungen eines archivierten Jahres (read-only, von GitHub),
/// neueste zuerst. Wird in der read-only-Ansicht angezeigt.
final archivedYearTransactionsProvider =
    FutureProvider.family<List<AppTransaction>, int>((ref, year) async {
  final data = await ref.watch(archiveRepositoryProvider).loadArchivedYear(year);
  final rows = (data['transactions'] as List?) ?? const [];
  final txs = [
    for (final r in rows)
      AppTransaction.fromJson(Map<String, dynamic>.from(r as Map)),
  ]..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));
  return txs;
});
