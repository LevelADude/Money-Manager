import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/models/account.dart';
import '../data/models/app_transaction.dart';

/// Leichtgewichtige, hand-gepflegte Lokalisierung (DE/EN).
///
/// Bewusst ohne Codegen/ARB: neue Texte = ein Getter mit `_t('Deutsch',
/// 'English')`. So lässt sich die Oberfläche Schritt für Schritt übersetzen.
/// Noch nicht umgestellte Screens bleiben vorerst deutsch.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [Locale('de'), Locale('en')];

  /// Alle Delegates (eigene + Flutter-Framework) für die MaterialApp.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  bool get _en => locale.languageCode == 'en';
  String _t(String de, String en) => _en ? en : de;

  // ---- Allgemein ----
  String get appTitle => 'Money Manager';
  String get save => _t('Speichern', 'Save');
  String get cancel => _t('Abbrechen', 'Cancel');

  // ---- Navigation ----
  String get navAccounts => _t('Konten', 'Accounts');
  String get navTransactions => _t('Buchungen', 'Transactions');
  String get navStatistics => _t('Statistik', 'Statistics');
  String get navMore => _t('Mehr', 'More');

  // ---- „Mehr"-Menü ----
  String get moreSearch => _t('Suche', 'Search');
  String get moreInsights => _t('Insights (Analyse)', 'Insights (analysis)');
  String get moreReminders => _t('Erinnerungen', 'Reminders');
  String get moreActivity => _t('Aktivität', 'Activity');
  String get moreBudgets => _t('Budgets', 'Budgets');
  String get morePlanning =>
      _t('Verfügbar & Fixkosten', 'Available & fixed costs');
  String get moreSimulator => _t('Was-wäre-wenn', 'What-if');
  String get moreProjects => _t('Projekte / Reisen', 'Projects / Trips');
  String get moreCashflow => _t('Cashflow-Kalender', 'Cashflow calendar');
  String get moreGoals => _t('Sparziele & Töpfe', 'Savings goals & jars');
  String get moreDebts => _t('Schulden & Kredite', 'Debts & loans');
  String get moreSettle =>
      _t('Ausgleich (wer schuldet wem)', 'Settle up (who owes whom)');
  String get moreRecurring => _t('Daueraufträge', 'Standing orders');
  String get moreSubscriptions => _t('Erkannte Abos', 'Detected subscriptions');
  String get moreCategories => _t('Kategorien', 'Categories');
  String get moreRules => _t('Auto-Kategorien (Regeln)', 'Auto-categories (rules)');
  String get moreExport => _t('Export (CSV)', 'Export (CSV)');
  String get moreImport => _t('CSV-Import', 'CSV import');
  String get moreTrash => _t('Papierkorb', 'Trash');
  String get moreBackup =>
      _t('Backup & Wiederherstellung', 'Backup & restore');
  String get moreSettings => _t('Einstellungen', 'Settings');
  String get moreProfile => _t('Profil', 'Profile');
  String get moreSharing =>
      _t('Freigaben (Zugriff teilen)', 'Sharing (share access)');
  String get moreAdmin => _t('Verwaltung (Admin)', 'Administration (admin)');
  String signedInAs(String email) =>
      _t('Angemeldet als $email', 'Signed in as $email');

  // ---- Einstellungen ----
  String get settingsTitle => _t('Einstellungen', 'Settings');
  String get appearance => _t('Erscheinungsbild', 'Appearance');
  String get themeSystem => _t('System', 'System');
  String get themeLight => _t('Hell', 'Light');
  String get themeDark => _t('Dunkel', 'Dark');
  String get accentColor => _t('Akzentfarbe', 'Accent color');
  String get privacy => _t('Privatsphäre', 'Privacy');
  String get hideAmounts => _t('Beträge verbergen', 'Hide amounts');
  String get hideAmountsSub =>
      _t('Zeigt „••••" statt Geldbeträgen', 'Shows "••••" instead of amounts');
  String get currency => _t('Währung', 'Currency');
  String get mainCurrency => _t('Hauptwährung', 'Main currency');
  String get mainCurrencyHelp => _t('Summen werden in diese Währung umgerechnet.',
      'Totals are converted to this currency.');
  String get addCurrency =>
      _t('Eigene Währung hinzufügen', 'Add custom currency');
  String get manageRates => _t('Wechselkurse verwalten', 'Manage exchange rates');
  String get appLock => _t('App-Sperre (PIN)', 'App lock (PIN)');
  String get appLockSub => _t('PIN-Abfrage beim Start und nach Pause',
      'PIN prompt on start and after pause');
  String get changePin => _t('PIN ändern', 'Change PIN');
  String get setPinTitle => _t('PIN festlegen', 'Set PIN');
  String get pinLabel => _t('PIN (4–6 Ziffern)', 'PIN (4–6 digits)');
  String get pinRepeat => _t('PIN wiederholen', 'Repeat PIN');
  String get pinMin => _t('Mindestens 4 Ziffern', 'At least 4 digits');
  String get pinDigitsOnly => _t('Nur Ziffern', 'Digits only');
  String get pinMismatch => _t('Stimmt nicht überein', 'Does not match');
  String get database => _t('Datenbank', 'Database');
  String get dbConnection => _t('Datenbank-Verbindung', 'Database connection');
  String get dbConnectionSub => _t(
      'Andere Supabase-Datenbank verbinden oder Verbindung trennen (nur dieses Gerät, Daten bleiben erhalten)',
      'Connect a different Supabase database or disconnect (this device only, data is kept)');
  String get language => _t('Sprache', 'Language');
  String get languageGerman => 'Deutsch';
  String get languageEnglish => 'English';

  // ---- Login ----
  String get email => _t('E-Mail', 'Email');
  String get password => _t('Passwort', 'Password');
  String get signIn => _t('Anmelden', 'Sign in');
  String get register => _t('Registrieren', 'Register');
  String get displayNameOptional =>
      _t('Anzeigename (optional)', 'Display name (optional)');
  String get haveAccount =>
      _t('Schon ein Konto? Anmelden', 'Already have an account? Sign in');
  String get newHere => _t('Neu hier? Konto erstellen', 'New here? Create account');
  String get forgotPassword => _t('Passwort vergessen?', 'Forgot password?');
  String get invalidEmail => _t('Gültige E-Mail eingeben', 'Enter a valid email');
  String get passwordMin => _t('Mind. 6 Zeichen', 'Min. 6 characters');
  String get changeDbConnection =>
      _t('Datenbank-Verbindung ändern', 'Change database connection');
  String get resetPasswordTitle =>
      _t('Passwort zurücksetzen', 'Reset password');
  String get sendLink => _t('Link senden', 'Send link');
  String get resetSent => _t(
      'E-Mail zum Zurücksetzen gesendet (falls registriert).',
      'Password reset email sent (if registered).');
  String get almostDone => _t(
      'Fast geschafft! Bitte bestätige deine E-Mail, dann anmelden.',
      'Almost done! Please confirm your email, then sign in.');

  // ---- Insights ----
  String get insightsTitle => 'Insights';
  String get thisMonth => _t('Dieser Monat', 'This month');
  String get thisYear => _t('Dieses Jahr', 'This year');
  String get secWarning => _t('Achtung', 'Attention');
  String get secOverview => _t('Überblick', 'Overview');
  String get secHint => _t('Hinweise', 'Tips');
  String get insightsEmpty => _t(
      'Noch zu wenig Daten für Auswertungen. Erfasse ein paar Buchungen – dann erscheinen hier automatisch Hinweise.',
      'Not enough data yet. Add a few transactions and insights will appear here automatically.');
  String get insightsLocalNote => _t(
      'Alles wird lokal auf diesem Gerät berechnet – es werden keine Daten an Dritte gesendet.',
      'Everything is computed locally on this device – no data is sent to third parties.');

  // ---- Allgemeine Aktionen ----
  String get refresh => _t('Aktualisieren', 'Refresh');
  String get refreshed => _t('Aktualisiert', 'Refreshed');
  String get edit => _t('Bearbeiten', 'Edit');
  String get delete => _t('Löschen', 'Delete');
  String errorWith(Object e) => _t('Fehler: $e', 'Error: $e');

  // ---- Konten ----
  String get accountFab => _t('Konto', 'Account');
  String get sortAccounts => _t('Konten sortieren', 'Sort accounts');
  String get noAccounts => _t(
      'Noch keine Konten. Lege unten eines an.', 'No accounts yet. Add one below.');
  String get netWorth => _t('Gesamtvermögen', 'Net worth');
  String get wealthPerPerson => _t('Vermögen je Person', 'Wealth per person');
  String get unknownPerson => _t('Unbekannt', 'Unknown');
  String get sharedLabel => _t('geteilt', 'shared');
  String get archivedLabel => _t('archiviert', 'archived');
  String get activate => _t('Aktivieren', 'Activate');
  String get archive => _t('Archivieren', 'Archive');
  String deleteAccountTitle(String name) =>
      _t('„$name" löschen?', 'Delete "$name"?');
  String get deleteAccountBody => _t(
      'Alle Buchungen dieses Kontos werden ebenfalls entfernt. Das kann nicht rückgängig gemacht werden.',
      'All transactions of this account will be removed too. This cannot be undone.');

  String accountType(AccountType t) => switch (t) {
        AccountType.bank => _t('Bankkonto', 'Bank account'),
        AccountType.cash => _t('Bargeld', 'Cash'),
        AccountType.creditCard => _t('Kreditkarte', 'Credit card'),
        AccountType.savings => _t('Sparkonto', 'Savings account'),
        AccountType.loan => _t('Kredit / Darlehen', 'Loan'),
        AccountType.investment => _t('Depot / Investment', 'Investment'),
        AccountType.wallet => _t('E-Wallet', 'E-wallet'),
        AccountType.other => _t('Sonstiges', 'Other'),
      };

  // ---- Buchungen (Liste) ----
  String get transactionFab => _t('Buchung', 'Transaction');
  String get today => _t('Heute', 'Today');
  String get periodAsPdf => _t('Zeitraum als PDF', 'Period as PDF');
  String pdfError(Object e) => _t('PDF-Fehler: $e', 'PDF error: $e');
  String get periodDay => _t('Tag', 'Day');
  String get periodWeek => _t('Woche', 'Week');
  String get periodMonth => _t('Monat', 'Month');
  String get periodYear => _t('Jahr', 'Year');
  String get income => _t('Einnahmen', 'Income');
  String get expenses => _t('Ausgaben', 'Expenses');
  String get balance => _t('Saldo', 'Balance');
  String get searchHint => _t('Suchen …', 'Search …');
  String get splitLabel => _t('Aufgeteilt', 'Split');
  String get noTransactionsPeriod => _t(
      'Keine Buchungen in diesem Zeitraum.', 'No transactions in this period.');
  String get pdfHeading =>
      _t('Money Manager – Buchungen', 'Money Manager – Transactions');
  String txCount(int n) => _t('$n Buchungen', '$n transactions');

  String transactionType(TransactionType t) => switch (t) {
        TransactionType.income => _t('Einnahme', 'Income'),
        TransactionType.expense => _t('Ausgabe', 'Expense'),
        TransactionType.transfer => _t('Übertrag', 'Transfer'),
      };

  List<String> get _monthNames => _en
      ? const [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December',
        ]
      : const [
          'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
          'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
        ];

  List<String> get _weekdayNames => _en
      ? const [
          'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
          'Saturday', 'Sunday',
        ]
      : const [
          'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag',
          'Samstag', 'Sonntag',
        ];

  String monthName(int month) => _monthNames[month - 1];

  List<String> get monthAbbr => _en
      ? const [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ]
      : const [
          'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
          'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
        ];

  List<String> get weekdayAbbr => _en
      ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
      : const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  /// Wochentag + Datum, z. B. „Montag, 18.06.2026" / „Monday, 18.06.2026".
  String dayHeader(DateTime d) {
    final wd = _weekdayNames[d.weekday - 1];
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$wd, $dd.$mm.${d.year}';
  }

  // ---- Statistik ----
  String get allTime => _t('Gesamt', 'All');
  String get back => _t('Zurück', 'Back');
  String get forward => _t('Vor', 'Next');
  String get balanceInPeriod => _t('Saldo im Zeitraum', 'Balance in period');
  String get noCategory => _t('Ohne Kategorie', 'Uncategorized');
  String get netWorthTrend12 =>
      _t('Vermögensverlauf (12 Monate)', 'Net worth trend (12 months)');
  String get tooFewData => _t('Noch zu wenige Daten.', 'Not enough data yet.');
  String get moneyFlow =>
      _t('Geldfluss (Einnahmen → Ausgaben)', 'Money flow (income → expenses)');
  String get other => _t('Sonstige', 'Other');
  String get heatmapMonth =>
      _t('Ausgaben-Heatmap (Monat)', 'Spending heatmap (month)');
  String get heatmapYear =>
      _t('Ausgaben-Heatmap (Jahr)', 'Spending heatmap (year)');
  String get less => _t('weniger', 'less');
  String get more => _t('mehr', 'more');
  String get monthlyTrend12 =>
      _t('Monatstrend (letzte 12 Monate)', 'Monthly trend (last 12 months)');
  String get noDataYet => _t('Noch keine Daten.', 'No data yet.');
  String get expensesByCategory =>
      _t('Ausgaben nach Kategorie', 'Expenses by category');
  String get incomeByCategory =>
      _t('Einnahmen nach Kategorie', 'Income by category');
  String get noData => _t('Keine Daten.', 'No data.');
  String get total => _t('Gesamt', 'Total');
  String get chartDonut => _t('Donut', 'Donut');
  String get chartPie => _t('Kreis', 'Pie');
  String get chartBars => _t('Balken', 'Bars');
  String get totalDebt => _t('Schulden gesamt', 'Total debt');
  String get topExpenses => _t('Größte Ausgaben', 'Top expenses');
  String get noPrevValue => _t('kein Vorwert', 'no previous value');
  String comparisonTo(String prev) =>
      _t('Vergleich zum $prev', 'Compared to $prev');
  String get prevDay => _t('Vortag', 'previous day');
  String get prevWeek => _t('Vorwoche', 'previous week');
  String get prevMonth => _t('Vormonat', 'previous month');
  String get prevYear => _t('Vorjahr', 'previous year');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'de' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
