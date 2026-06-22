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

  // ---- Buchungsformular ----
  String get newTransaction => _t('Neue Buchung', 'New transaction');
  String get editTransaction => _t('Buchung bearbeiten', 'Edit transaction');
  String get saveAsTemplate => _t('Als Vorlage speichern', 'Save as template');
  String get history => _t('Verlauf', 'History');
  String get duplicate => _t('Duplizieren', 'Duplicate');
  String get createAccountFirst =>
      _t('Bitte zuerst ein Konto anlegen.', 'Please create an account first.');
  String get fromTemplate => _t('Aus Vorlage', 'From template');
  String get accountLabel => _t('Konto', 'Account');
  String get amountHintLabel =>
      _t('Betrag (auch Rechnung, z. B. 12,50+3)', 'Amount (math ok, e.g. 12.50+3)');
  String get calculator => _t('Taschenrechner', 'Calculator');
  String get enterValidAmount =>
      _t('Gültigen Betrag eingeben', 'Enter a valid amount');
  String get targetAccount => _t('Zielkonto', 'Target account');
  String get chooseDash => _t('— wählen —', '— choose —');
  String get splitMultiple =>
      _t('Auf mehrere Kategorien aufteilen', 'Split across multiple categories');
  String get category => _t('Kategorie', 'Category');
  String get noCategoryOption => _t('Keine Kategorie', 'No category');
  String get titleHintLabel =>
      _t('Titel (z. B. Aldi, Rewe, Aral)', 'Title (e.g. Aldi, Rewe, Aral)');
  String get note => _t('Notiz', 'Note');
  String get dateLabel => _t('Datum', 'Date');
  String get chooseAccount => _t('Bitte ein Konto wählen.', 'Please choose an account.');
  String get chooseTargetAccount =>
      _t('Bitte ein Zielkonto wählen.', 'Please choose a target account.');
  String splitSumMismatch(String sum, String amount) => _t(
      'Summe der Aufteilungen ($sum) muss dem Betrag ($amount) entsprechen.',
      'Split total ($sum) must equal the amount ($amount).');
  String get deleteTransactionTitle =>
      _t('Buchung löschen?', 'Delete transaction?');
  String get cannotUndo =>
      _t('Das kann nicht rückgängig gemacht werden.', 'This cannot be undone.');
  String get noHistory => _t('Kein Verlauf vorhanden.', 'No history available.');
  String get templateNameLabel => _t('Name der Vorlage', 'Template name');
  String get templateSaved => _t('Vorlage gespeichert', 'Template saved');
  String get chooseTemplate => _t('Vorlage wählen', 'Choose template');
  String get noTemplates => _t(
      'Noch keine Vorlagen. Speichere eine über das Lesezeichen-Symbol oben.',
      'No templates yet. Save one via the bookmark icon at the top.');
  String get enterValidValuesFirst => _t(
      'Bitte zuerst gültige Werte eingeben.', 'Please enter valid values first.');
  String get transactionDuplicated =>
      _t('Buchung dupliziert', 'Transaction duplicated');
  String get cameraTakePhoto =>
      _t('Kamera (Foto aufnehmen)', 'Camera (take photo)');
  String get galleryFile => _t('Galerie / Datei', 'Gallery / file');
  String receiptError(Object e) => _t('Beleg-Fehler: $e', 'Receipt error: $e');
  String receiptRecognized(String fields) => _t(
      'Beleg erkannt – $fields übernommen.', 'Receipt scanned – $fields filled in.');
  String get fieldAmount => _t('Betrag', 'Amount');
  String get fieldTitle => _t('Titel', 'Title');
  String get fieldDate => _t('Datum', 'Date');
  String get receipt => _t('Beleg', 'Receipt');
  String get receiptLoadFailed =>
      _t('Beleg konnte nicht geladen werden', 'Receipt could not be loaded');
  String get replace => _t('Ersetzen', 'Replace');
  String get remove => _t('Entfernen', 'Remove');
  String get addReceipt => _t('Beleg / Foto hinzufügen', 'Add receipt / photo');
  String get none => _t('Keine', 'None');
  String get amount => _t('Betrag', 'Amount');
  String get removeRow => _t('Zeile entfernen', 'Remove row');
  String get rowLabel => _t('Zeile', 'Row');
  String rest(String x) => _t('Rest $x', 'Remainder $x');
  String distributedBalanced(String x) =>
      _t('Verteilt: $x ✓', 'Allocated: $x ✓');
  String distributedOf(String x, String y, String z) => _t(
      'Verteilt: $x von $y · Rest $z', 'Allocated: $x of $y · remainder $z');

  String auditAction(String action) => switch (action) {
        'insert' => _t('Angelegt', 'Created'),
        'delete' => _t('Gelöscht', 'Deleted'),
        'restore' => _t('Wiederhergestellt', 'Restored'),
        'purge' => _t('Endgültig gelöscht', 'Purged'),
        _ => _t('Geändert', 'Edited'),
      };

  // ---- Konto-Formular / -Detail ----
  String get newAccount => _t('Neues Konto', 'New account');
  String get editAccount => _t('Konto bearbeiten', 'Edit account');
  String get name => _t('Name', 'Name');
  String get enterName => _t('Name eingeben', 'Enter a name');
  String get accountTypeLabel => _t('Kontotyp', 'Account type');
  String get openingBalance => _t('Anfangssaldo', 'Opening balance');
  String get openingBalanceHelp => _t(
      'Aktueller Stand des Kontos beim Anlegen',
      'Current balance of the account when created');
  String get openingBalanceLiabilityHelp => _t(
      'Bestehende Schuld als negativen Wert eingeben, z. B. -500',
      'Enter an existing debt as a negative value, e.g. -500');
  String get creditLimitOptional =>
      _t('Kreditrahmen (optional)', 'Credit limit (optional)');
  String get countsToNetWorth =>
      _t('Zählt zum Gesamtvermögen', 'Counts toward net worth');
  String get shareWithTitle =>
      _t('Teilen mit (Gemeinschaftskonto)', 'Share with (joint account)');
  String get shareWithHelp => _t(
      'Ausgewählte Personen sehen dieses Konto und dürfen darauf buchen.',
      'Selected people can see this account and post transactions to it.');
  String get noTransactions =>
      _t('Noch keine Buchungen.', 'No transactions yet.');
  String byAuthor(String name) => _t('von $name', 'by $name');
  String amountOf(String a, String b) => _t('$a von $b', '$a of $b');

  // ---- Budgets ----
  String budgetDialogTitle(String name) => 'Budget: $name';
  String get monthlyBudget => _t('Monatsbudget', 'Monthly budget');
  String get thisMonthWithBudget =>
      _t('Diesen Monat (mit Budget)', 'This month (with budget)');
  String get setBudgetAction => _t('Budget setzen', 'Set budget');
  String budgetExceededBy(String x) =>
      _t('Budget um $x überschritten', 'Budget exceeded by $x');
  String budgetRemainingLine(String remaining, int days, String perDay) => _t(
      'Noch $remaining · $days Tage übrig · $perDay/Tag',
      'Remaining $remaining · $days days left · $perDay/day');
  String overBy(String x) => _t('+$x über', '+$x over');
  String amountLeft(String x) => _t('noch $x', '$x left');
  String noBudgetThisMonth(String x) =>
      _t('Kein Budget · diesen Monat $x', 'No budget · this month $x');

  // ---- Sparziele ----
  String get roundupSaving => _t('Rundungs-Sparen', 'Round-up saving');
  String get newItem => _t('Neu', 'New');
  String get targetAmountHint =>
      _t('Zielbetrag (leer = offener Topf)', 'Target amount (empty = open jar)');
  String get noTargetDate => _t('Kein Zieldatum', 'No target date');
  String targetDateLabel(String date) => _t('Ziel: $date', 'Target: $date');
  String get deposit => _t('Einzahlen', 'Deposit');
  String get withdraw => _t('Abheben', 'Withdraw');
  String get noRoundupThisMonth =>
      _t('Kein Rundungsbetrag in diesem Monat.', 'No round-up amount this month.');
  String get createGoalFirst => _t('Lege zuerst ein Sparziel oder einen Topf an.',
      'Create a savings goal or jar first.');
  String roundupThisMonth(String x) => _t(
      'Aufrundung der Ausgaben diesen Monat: $x',
      'Round-up of this month\'s expenses: $x');
  String get depositInto => _t('Einzahlen in', 'Deposit into');
  String depositedInto(String x, String name) =>
      _t('$x in „$name" eingezahlt', '$x deposited into "$name"');
  String get noGoals =>
      _t('Noch keine Sparziele. Lege unten eines an.', 'No savings goals yet. Add one below.');
  String get openPot => _t('Offener Topf', 'Open jar');
  String perMonthNeeded(String x) => _t('$x/Monat nötig', '$x/month needed');
  String get ofWithSpace => _t('von ', 'of ');
  String get goalReached => _t('Ziel erreicht! 🎉', 'Goal reached! 🎉');
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
