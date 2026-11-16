// Beispieldaten und Provider-Overrides für die Design-Vorschau
// (`dev_preview.dart`) und die Widget-Tests der Hauptscreens.
//
// Ersetzt alle Quellen, die sonst Supabase bräuchten, durch feste Werte. Wird
// von der App selbst nicht importiert und landet daher nicht im Release-Build.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'data/local/app_cache.dart';
import 'data/models/account.dart';
import 'data/models/account_group.dart';
import 'data/models/app_transaction.dart';
import 'data/models/archive_config_status.dart';
import 'data/models/archived_year.dart';
import 'data/models/category.dart';
import 'features/accounts/account_providers.dart';
import 'features/archive/archive_providers.dart';
import 'features/auth/auth_providers.dart';
import 'features/budgets/budget_providers.dart';
import 'features/categories/category_providers.dart';
import 'features/currency/currency_providers.dart';
import 'features/profile/profile_providers.dart';
import 'features/recurring/recurring_providers.dart';
import 'features/reminders/reminders_providers.dart';
import 'features/reservations/reservation_providers.dart';
import 'features/savings/savings_providers.dart';
import 'features/sharing/access_grant_providers.dart';
import 'features/sharing/account_member_providers.dart';
import 'features/transactions/transaction_providers.dart';

const previewUserId = 'preview-me';
const _partnerId = 'preview-partner';

Account _acc(
  String id,
  String name,
  AccountType type,
  int openingCents, {
  String owner = previewUserId,
}) => Account(
  id: id,
  ownerId: owner,
  name: name,
  type: type,
  currency: 'EUR',
  openingBalanceCents: openingCents,
  icon: null,
  color: null,
  creditLimitCents: null,
  includeInNetWorth: true,
  archived: false,
);

final previewAccounts = <Account>[
  _acc('giro', 'Girokonto', AccountType.bank, 120000),
  _acc('spar', 'Sparkonto', AccountType.savings, 900000),
  _acc('bar', 'Bargeld', AccountType.cash, 8000),
  _acc('depot', 'Depot', AccountType.investment, 450000, owner: _partnerId),
  _acc('karte', 'Kreditkarte', AccountType.creditCard, -32000),
];

Category _cat(String id, String name, CategoryKind kind, String emoji) =>
    Category(
      id: id,
      name: name,
      kind: kind,
      parentId: null,
      icon: null,
      color: null,
      isPreset: false,
      active: true,
      emoji: emoji,
    );

final previewCategories = <Category>[
  _cat('food', 'Lebensmittel', CategoryKind.expense, '🛒'),
  _cat('cafe', 'Essen gehen', CategoryKind.expense, '☕'),
  _cat('move', 'Mobilität', CategoryKind.expense, '🚆'),
  _cat('home', 'Wohnen', CategoryKind.expense, '🏠'),
  _cat('fun', 'Freizeit', CategoryKind.expense, '🎬'),
  _cat('subs', 'Abos', CategoryKind.expense, '🎵'),
  _cat('pay', 'Einkommen', CategoryKind.income, '💼'),
];

/// Buchungen der letzten Monate relativ zu [now], damit Zeitraum-Ansichten
/// immer etwas zeigen.
List<AppTransaction> previewTransactions(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  var n = 0;
  AppTransaction tx(
    int daysAgo,
    TransactionType type,
    int cents,
    String title,
    String? cat, {
    String account = 'giro',
    String? to,
    List<String> tags = const [],
  }) => AppTransaction(
    id: 'tx${n++}',
    accountId: account,
    type: type,
    amountCents: cents,
    occurredOn: today.subtract(Duration(days: daysAgo)),
    categoryId: cat,
    transferAccountId: to,
    title: title,
    note: '',
    createdBy: previewUserId,
    receiptPath: null,
    tags: tags,
  );
  const exp = TransactionType.expense;
  const inc = TransactionType.income;
  return [
    tx(0, exp, 4218, 'REWE City', 'food', tags: ['Haushalt']),
    tx(0, exp, 790, 'Café Extrablatt', 'cafe', account: 'bar'),
    tx(1, exp, 5800, 'Deutschlandticket', 'move'),
    tx(2, inc, 295000, 'Gehalt', 'pay'),
    tx(2, exp, 2400, 'Kino Cinestar', 'fun', account: 'karte'),
    tx(2, exp, 1849, 'dm Drogerie', 'food'),
    tx(2, TransactionType.transfer, 30000, 'Auf Sparkonto', null, to: 'spar'),
    tx(3, exp, 72500, 'Miete', 'home'),
    tx(3, exp, 1099, 'Spotify', 'subs'),
    tx(4, exp, 3650, '', 'food'),
    tx(6, exp, 1290, 'Bäckerei', null, account: 'bar'),
    // Frühere Monate für Verlauf und Vergleich.
    for (var m = 1; m <= 8; m++) ...[
      tx(30 * m + 2, inc, 295000, 'Gehalt', 'pay'),
      tx(30 * m + 3, exp, 72500, 'Miete', 'home'),
      tx(30 * m + 5, exp, 21000 + 2300 * m, 'Wocheneinkauf', 'food'),
      tx(30 * m + 9, exp, 5800, 'Deutschlandticket', 'move'),
      tx(30 * m + 12, exp, 4000 + 900 * (m % 3), 'Ausgehen', 'fun'),
    ],
  ];
}

/// Overrides, mit denen die vier Hauptscreens ohne Login und ohne Netz laufen.
List<Override> previewOverrides(SharedPreferences prefs, {DateTime? now}) {
  final txs = previewTransactions(now ?? DateTime.now());
  return [
    sharedPrefsProvider.overrideWithValue(prefs),
    // Wird nie abgefragt (alle Datenquellen sind unten ersetzt); die Screens
    // lesen daraus nur den angemeldeten Nutzer.
    supabaseClientProvider.overrideWithValue(
      SupabaseClient(
        'http://127.0.0.1:9',
        'preview',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ),
    authStateChangesProvider.overrideWith((ref) => const Stream.empty()),
    currentUserIdProvider.overrideWithValue(previewUserId),
    accountsProvider.overrideWith((ref) => Stream.value(previewAccounts)),
    allTransactionsProvider.overrideWith((ref) => Stream.value(txs)),
    allSplitsProvider.overrideWith((ref) => Stream.value(const [])),
    commentsProvider.overrideWith((ref, txId) => Stream.value(const [])),
    categoriesRawProvider.overrideWith(
      (ref) => Stream.value(previewCategories),
    ),
    categoryPrefsProvider.overrideWith((ref) => Stream.value(const {})),
    accountGroupsProvider.overrideWith(
      (ref) => const [
        AccountGroup(id: 'g1', name: 'Flüssig', accountIds: ['giro', 'bar']),
        AccountGroup(id: 'g2', name: 'Rücklagen', accountIds: ['spar']),
      ],
    ),
    profileNamesProvider.overrideWith(
      (ref) => const {previewUserId: 'Alex', _partnerId: 'Sam'},
    ),
    isAdminProvider.overrideWith((ref) => true),
    isReadOnlyProvider.overrideWith((ref) => false),
    manageableOwnersProvider.overrideWithValue(const {previewUserId}),
    membersByAccountProvider.overrideWithValue(const {}),
    archivedCarryoverProvider.overrideWithValue(const {}),
    // Archiv- und Profilseite.
    appConfigProvider.overrideWithValue(AppConfig(prefs)),
    myDisplayNameProvider.overrideWith((ref) => 'Vorschau'),
    archiveConfigStatusProvider.overrideWith(
      (ref) => const ArchiveConfigStatus(
        configured: true,
        repo: 'beispiel/archiv',
        hasToken: true,
        hasKey: true,
      ),
    ),
    archivedYearsProvider.overrideWith(
      (ref) => Stream.value([
        ArchivedYear(
          year: 2020,
          archivedAt: DateTime(2021, 1, 15),
          txCount: 412,
          byteSize: 48200,
          carryoverByAccount: const {},
        ),
      ]),
    ),
    reservationsStreamProvider.overrideWith((ref) => Stream.value(const [])),
    reservationTopupProvider.overrideWith((ref) => 0),
    recurringGenerationProvider.overrideWith((ref) => 0),
    // Insights lesen zusätzlich Budgets, Daueraufträge und Sparziele.
    budgetsProvider.overrideWith((ref) => Stream.value(const [])),
    recurringRulesProvider.overrideWith((ref) => Stream.value(const [])),
    savingsGoalsProvider.overrideWith((ref) => Stream.value(const [])),
    remindersProvider.overrideWithValue(const []),
    converterProvider.overrideWithValue((cents, code) => cents),
    effectiveRatesProvider.overrideWithValue(const {}),
  ];
}
