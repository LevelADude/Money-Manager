import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/account.dart';
import '../../data/models/reservation.dart';
import '../../data/repositories/reservation_repository.dart';
import '../accounts/account_providers.dart';
import '../auth/auth_providers.dart';
import '../currency/currency_providers.dart';
import '../settings/settings_providers.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
  );
});

final reservationsStreamProvider = StreamProvider<List<Reservation>>((ref) {
  return ref.watch(reservationRepositoryProvider).watchReservations();
});

/// Alle sichtbaren Reservierungen auf (nicht gelöschten) Konten, nach
/// Fälligkeit sortiert (ohne Datum zuletzt).
final reservationsProvider = Provider<List<Reservation>>((ref) {
  final all =
      ref.watch(reservationsStreamProvider).value ?? const <Reservation>[];
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  final ids = {for (final a in accounts) a.id};
  final list = all.where((r) => ids.contains(r.accountId)).toList()
    ..sort((a, b) {
      final da = a.dueOn, db = b.dueOn;
      if (da == null && db == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
  return list;
});

/// Reservierungen eines Kontos.
final accountReservationsProvider = Provider.family<List<Reservation>, String>((
  ref,
  accountId,
) {
  return ref
      .watch(reservationsProvider)
      .where((r) => r.accountId == accountId)
      .toList();
});

/// Offen reservierter Betrag je Konto (Konto-ID -> Cent, Kontowährung).
final reservedByAccountProvider = Provider<Map<String, int>>((ref) {
  return reservedByAccount(ref.watch(reservationsProvider));
});

/// Verfügbarer Saldo je Konto (Saldo - Reserviert).
final availableBalancesProvider = Provider<Map<String, int>>((ref) {
  return availableBalances(
    ref.watch(accountBalancesProvider),
    ref.watch(reservedByAccountProvider),
  );
});

/// Die Salden, die laut Einstellung groß angezeigt werden (verfügbar oder
/// gesamt). Für Summen, die nur einen Wert zeigen (Kategorien, Gruppen ...).
final primaryBalancesProvider = Provider<Map<String, int>>((ref) {
  final showAvailable = ref.watch(
    settingsProvider.select((s) => s.showAvailable),
  );
  return showAvailable
      ? ref.watch(availableBalancesProvider)
      : ref.watch(accountBalancesProvider);
});

/// Gesamt reserviert (Hauptwährung) über alle Konten, die ins Vermögen
/// zählen, optional nur für eine Person.
final reservedNetWorthProvider = Provider.family<int, String?>((ref, ownerId) {
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  final convert = ref.watch(converterProvider);
  final reserved = ref.watch(reservedByAccountProvider);
  var total = 0;
  for (final a in accounts) {
    if (!a.includeInNetWorth || a.archived) continue;
    if (ownerId != null && a.ownerId != ownerId) continue;
    final r = reserved[a.id];
    if (r != null) total += convert(r, a.currency);
  }
  return total;
});

/// Konten, auf denen mehr reserviert ist als vorhanden (bzw. als der
/// Kreditrahmen hergibt).
final overReservedAccountsProvider = Provider<Set<String>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  final balances = ref.watch(accountBalancesProvider);
  final reserved = ref.watch(reservedByAccountProvider);
  return {
    for (final a in accounts)
      if (isOverReserved(
        balanceCents: balances[a.id] ?? 0,
        reservedCents: reserved[a.id] ?? 0,
        isLiability: a.type.isLiability,
        creditLimitCents: a.creditLimitCents,
      ))
        a.id,
  };
});

/// Fällige wiederkehrende Rücklagen beim App-Start einmalig fortschreiben.
final reservationTopupProvider = FutureProvider<int>((ref) {
  return ref.watch(reservationRepositoryProvider).applyTopups();
});
