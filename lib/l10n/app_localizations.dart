import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/models/account.dart';
import '../data/models/app_transaction.dart';
import '../data/models/recurring_rule.dart';

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
  String get moreRules =>
      _t('Auto-Kategorien (Regeln)', 'Auto-categories (rules)');
  String get moreExport => _t('Export (CSV)', 'Export (CSV)');
  String get moreImport => _t('CSV-Import', 'CSV import');
  String get moreTrash => _t('Papierkorb', 'Trash');
  String get moreBackup => _t('Backup & Wiederherstellung', 'Backup & restore');
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
  String get mainCurrencyHelp => _t(
    'Summen werden in diese Währung umgerechnet.',
    'Totals are converted to this currency.',
  );
  String get addCurrency =>
      _t('Eigene Währung hinzufügen', 'Add custom currency');
  String get manageRates =>
      _t('Wechselkurse verwalten', 'Manage exchange rates');
  String get appLock => _t('App-Sperre (PIN)', 'App lock (PIN)');
  String get appLockSub => _t(
    'PIN-Abfrage beim Start und nach Pause',
    'PIN prompt on start and after pause',
  );
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
    'Connect a different Supabase database or disconnect (this device only, data is kept)',
  );
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
  String get newHere =>
      _t('Neu hier? Konto erstellen', 'New here? Create account');
  String get forgotPassword => _t('Passwort vergessen?', 'Forgot password?');
  String get invalidEmail =>
      _t('Gültige E-Mail eingeben', 'Enter a valid email');
  String get passwordMin => _t('Mind. 6 Zeichen', 'Min. 6 characters');
  String get changeDbConnection =>
      _t('Datenbank-Verbindung ändern', 'Change database connection');
  String get resetPasswordTitle =>
      _t('Passwort zurücksetzen', 'Reset password');
  String get sendLink => _t('Link senden', 'Send link');
  String get resetSent => _t(
    'E-Mail zum Zurücksetzen gesendet (falls registriert).',
    'Password reset email sent (if registered).',
  );
  String get almostDone => _t(
    'Fast geschafft! Bitte bestätige deine E-Mail, dann anmelden.',
    'Almost done! Please confirm your email, then sign in.',
  );

  // ---- Insights ----
  String get insightsTitle => 'Insights';
  String get thisMonth => _t('Dieser Monat', 'This month');
  String get thisYear => _t('Dieses Jahr', 'This year');
  String get secWarning => _t('Achtung', 'Attention');
  String get secOverview => _t('Überblick', 'Overview');
  String get secHint => _t('Hinweise', 'Tips');
  String get insightsEmpty => _t(
    'Noch zu wenig Daten für Auswertungen. Erfasse ein paar Buchungen – dann erscheinen hier automatisch Hinweise.',
    'Not enough data yet. Add a few transactions and insights will appear here automatically.',
  );
  String get insightsLocalNote => _t(
    'Alles wird lokal auf diesem Gerät berechnet – es werden keine Daten an Dritte gesendet.',
    'Everything is computed locally on this device – no data is sent to third parties.',
  );

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
    'Noch keine Konten. Lege unten eines an.',
    'No accounts yet. Add one below.',
  );
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
    'All transactions of this account will be removed too. This cannot be undone.',
  );

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
    'Keine Buchungen in diesem Zeitraum.',
    'No transactions in this period.',
  );
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
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ]
      : const [
          'Januar',
          'Februar',
          'März',
          'April',
          'Mai',
          'Juni',
          'Juli',
          'August',
          'September',
          'Oktober',
          'November',
          'Dezember',
        ];

  List<String> get _weekdayNames => _en
      ? const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ]
      : const [
          'Montag',
          'Dienstag',
          'Mittwoch',
          'Donnerstag',
          'Freitag',
          'Samstag',
          'Sonntag',
        ];

  String monthName(int month) => _monthNames[month - 1];

  List<String> get monthAbbr => _en
      ? const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ]
      : const [
          'Jan',
          'Feb',
          'Mär',
          'Apr',
          'Mai',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Okt',
          'Nov',
          'Dez',
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
  String get amountHintLabel => _t(
    'Betrag (auch Rechnung, z. B. 12,50+3)',
    'Amount (math ok, e.g. 12.50+3)',
  );
  String get calculator => _t('Taschenrechner', 'Calculator');
  String get enterValidAmount =>
      _t('Gültigen Betrag eingeben', 'Enter a valid amount');
  String get targetAccount => _t('Zielkonto', 'Target account');
  String get chooseDash => _t('— wählen —', '— choose —');
  String get splitMultiple => _t(
    'Auf mehrere Kategorien aufteilen',
    'Split across multiple categories',
  );
  String get category => _t('Kategorie', 'Category');
  String get noCategoryOption => _t('Keine Kategorie', 'No category');
  String get titleHintLabel =>
      _t('Titel (z. B. Aldi, Rewe, Aral)', 'Title (e.g. Aldi, Rewe, Aral)');
  String get note => _t('Notiz', 'Note');
  String get dateLabel => _t('Datum', 'Date');
  String get chooseAccount =>
      _t('Bitte ein Konto wählen.', 'Please choose an account.');
  String get chooseTargetAccount =>
      _t('Bitte ein Zielkonto wählen.', 'Please choose a target account.');
  String splitSumMismatch(String sum, String amount) => _t(
    'Summe der Aufteilungen ($sum) muss dem Betrag ($amount) entsprechen.',
    'Split total ($sum) must equal the amount ($amount).',
  );
  String get deleteTransactionTitle =>
      _t('Buchung löschen?', 'Delete transaction?');
  String get cannotUndo =>
      _t('Das kann nicht rückgängig gemacht werden.', 'This cannot be undone.');
  String get noHistory =>
      _t('Kein Verlauf vorhanden.', 'No history available.');
  String get templateNameLabel => _t('Name der Vorlage', 'Template name');
  String get templateSaved => _t('Vorlage gespeichert', 'Template saved');
  String get chooseTemplate => _t('Vorlage wählen', 'Choose template');
  String get noTemplates => _t(
    'Noch keine Vorlagen. Speichere eine über das Lesezeichen-Symbol oben.',
    'No templates yet. Save one via the bookmark icon at the top.',
  );
  String get enterValidValuesFirst => _t(
    'Bitte zuerst gültige Werte eingeben.',
    'Please enter valid values first.',
  );
  String get transactionDuplicated =>
      _t('Buchung dupliziert', 'Transaction duplicated');
  String get cameraTakePhoto =>
      _t('Kamera (Foto aufnehmen)', 'Camera (take photo)');
  String get galleryFile => _t('Galerie / Datei', 'Gallery / file');
  String receiptError(Object e) => _t('Beleg-Fehler: $e', 'Receipt error: $e');
  String receiptRecognized(String fields) => _t(
    'Beleg erkannt – $fields übernommen.',
    'Receipt scanned – $fields filled in.',
  );
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
  String distributedOf(String x, String y, String z) =>
      _t('Verteilt: $x von $y · Rest $z', 'Allocated: $x of $y · remainder $z');

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
    'Current balance of the account when created',
  );
  String get openingBalanceLiabilityHelp => _t(
    'Bestehende Schuld als negativen Wert eingeben, z. B. -500',
    'Enter an existing debt as a negative value, e.g. -500',
  );
  String get creditLimitOptional =>
      _t('Kreditrahmen (optional)', 'Credit limit (optional)');
  String get countsToNetWorth =>
      _t('Zählt zum Gesamtvermögen', 'Counts toward net worth');
  String get shareWithTitle =>
      _t('Teilen mit (Gemeinschaftskonto)', 'Share with (joint account)');
  String get shareWithHelp => _t(
    'Ausgewählte Personen sehen dieses Konto und dürfen darauf buchen.',
    'Selected people can see this account and post transactions to it.',
  );
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
    'Remaining $remaining · $days days left · $perDay/day',
  );
  String overBy(String x) => _t('+$x über', '+$x over');
  String amountLeft(String x) => _t('noch $x', '$x left');
  String noBudgetThisMonth(String x) =>
      _t('Kein Budget · diesen Monat $x', 'No budget · this month $x');

  // ---- Sparziele ----
  String get roundupSaving => _t('Rundungs-Sparen', 'Round-up saving');
  String get newItem => _t('Neu', 'New');
  String get targetAmountHint => _t(
    'Zielbetrag (leer = offener Topf)',
    'Target amount (empty = open jar)',
  );
  String get noTargetDate => _t('Kein Zieldatum', 'No target date');
  String targetDateLabel(String date) => _t('Ziel: $date', 'Target: $date');
  String get deposit => _t('Einzahlen', 'Deposit');
  String get withdraw => _t('Abheben', 'Withdraw');
  String get noRoundupThisMonth => _t(
    'Kein Rundungsbetrag in diesem Monat.',
    'No round-up amount this month.',
  );
  String get createGoalFirst => _t(
    'Lege zuerst ein Sparziel oder einen Topf an.',
    'Create a savings goal or jar first.',
  );
  String roundupThisMonth(String x) => _t(
    'Aufrundung der Ausgaben diesen Monat: $x',
    'Round-up of this month\'s expenses: $x',
  );
  String get depositInto => _t('Einzahlen in', 'Deposit into');
  String depositedInto(String x, String name) =>
      _t('$x in „$name" eingezahlt', '$x deposited into "$name"');
  String get noGoals => _t(
    'Noch keine Sparziele. Lege unten eines an.',
    'No savings goals yet. Add one below.',
  );
  String get openPot => _t('Offener Topf', 'Open jar');
  String perMonthNeeded(String x) => _t('$x/Monat nötig', '$x/month needed');
  String get ofWithSpace => _t('von ', 'of ');
  String get goalReached => _t('Ziel erreicht! 🎉', 'Goal reached! 🎉');

  // ---- Kategorien ----
  String get newCategory => _t('Neue Kategorie', 'New category');
  String get create => _t('Anlegen', 'Create');
  String get expenseSingular => _t('Ausgabe', 'Expense');
  String get incomeSingular => _t('Einnahme', 'Income');
  String get preset => _t('Vorlage', 'Preset');
  String get custom => _t('Eigene', 'Custom');

  // ---- Daueraufträge ----
  String get recurringFab => _t('Dauerauftrag', 'Standing order');
  String get noRecurring => _t(
    'Noch keine Daueraufträge.\nLege z. B. Miete oder Gehalt an.',
    'No standing orders yet.\nAdd e.g. rent or salary.',
  );
  String get paused => _t('pausiert', 'paused');
  String intervalUnitLabel(IntervalUnit u) => switch (u) {
    IntervalUnit.day => _t('Tag(e)', 'day(s)'),
    IntervalUnit.week => _t('Woche(n)', 'week(s)'),
    IntervalUnit.month => _t('Monat(e)', 'month(s)'),
    IntervalUnit.year => _t('Jahr(e)', 'year(s)'),
  };
  String everyInterval(int count, IntervalUnit unit) => _t(
    'alle $count ${intervalUnitLabel(unit)}',
    'every $count ${intervalUnitLabel(unit)}',
  );
  String nextDuePrefix(String date) => _t('nächste: $date', 'next: $date');

  // ---- Suche ----
  String get searchFieldHint => _t(
    'Suchen (Titel, Notiz, Tag, Konto, Betrag) …',
    'Search (title, note, tag, account, amount) …',
  );
  String get enterSearchTerm =>
      _t('Suchbegriff eingeben.', 'Enter a search term.');
  String get noResults => _t('Keine Treffer.', 'No results.');

  // ---- Erinnerungen ----
  String streakDays(int n) => _t('$n-Tage-Streak', '$n-day streak');
  String get bookedToday => _t(
    'Heute schon gebucht – weiter so!',
    'Already booked today – keep it up!',
  );
  String get notBookedToday =>
      _t('Heute noch nichts gebucht.', 'Nothing booked today yet.');
  String get bookAction => _t('Buchen', 'Book');
  String get noReminders =>
      _t('Keine offenen Erinnerungen 🎉', 'No open reminders 🎉');

  // ---- Papierkorb ----
  String get trashEmpty => _t(
    'Papierkorb ist leer.\n\nGelöschte Buchungen erscheinen hier 30 Tage lang und können wiederhergestellt werden.',
    'Trash is empty.\n\nDeleted transactions appear here for 30 days and can be restored.',
  );
  String deletedOn(String date) => _t('Gelöscht am $date', 'Deleted on $date');
  String get restore => _t('Wiederherstellen', 'Restore');
  String get purge => _t('Endgültig löschen', 'Delete permanently');

  // ---- Erkannte Abos ----
  String get noSubscriptions => _t(
    'Keine wiederkehrenden Muster erkannt.\n\nSobald sich eine Buchung (gleicher Titel + Betrag) regelmäßig wiederholt, wird sie hier als Dauerauftrag vorgeschlagen.',
    'No recurring patterns detected.\n\nWhen a transaction (same title + amount) repeats regularly, it will be suggested here as a standing order.',
  );
  String detectedTimes(int n) => _t('$n× erkannt', '$n× detected');
  String fromDate(String date) => _t('ab $date', 'from $date');
  String get recurringCreated =>
      _t('Dauerauftrag angelegt', 'Standing order created');

  // ---- Aktivität ----
  String get noActivity => _t('Noch keine Aktivität.', 'No activity yet.');
  String get transactionNoun => _t('Buchung', 'Transaction');

  // ---- Konten sortieren ----
  String get noAccountsShort => _t('Keine Konten.', 'No accounts.');

  // ---- Passwort zurücksetzen (neues Passwort) ----
  String get newPasswordTitle => _t('Neues Passwort', 'New password');
  String get setNewPasswordHint =>
      _t('Lege ein neues Passwort fest.', 'Set a new password.');
  String get newPasswordLabel => _t('Neues Passwort', 'New password');
  String get passwordUpdated => _t('Passwort aktualisiert', 'Password updated');

  // ---- Auto-Kategorien (Regeln) ----
  String get rulesTitle => _t('Auto-Kategorien', 'Auto-categories');
  String get ruleFab => _t('Regel', 'Rule');
  String get newRule => _t('Neue Regel', 'New rule');
  String get keywordLabel =>
      _t('Stichwort (im Titel enthalten)', 'Keyword (contained in title)');
  String get keywordHint => _t('z. B. Aldi', 'e.g. Aldi');
  String get noRules => _t(
    'Noch keine Regeln.\n\nLege fest, dass z. B. Titel mit „Aldi" automatisch der Kategorie „Lebensmittel" zugeordnet werden.',
    'No rules yet.\n\nDefine that e.g. titles containing "Aldi" are automatically assigned to the "Groceries" category.',
  );
  String containsKeyword(String kw) => _t('enthält „$kw"', 'contains "$kw"');

  // ---- Eigene Währung / Wechselkurse ----
  String get customCurrency => _t('Eigene Währung', 'Custom currency');
  String get currencyCodeLabel =>
      _t('Währungscode (z. B. BTC)', 'Currency code (e.g. BTC)');
  String get currencyCodeHelper => _t(
    'Kurs später unter „Wechselkurse" festlegen.',
    'Set the rate later under "Exchange rates".',
  );
  String get add => _t('Hinzufügen', 'Add');
  String get exchangeRatesTitle => _t('Wechselkurse', 'Exchange rates');
  String rateForCode(String code) => _t('Kurs für $code', 'Rate for $code');
  String mainCurrencyWith(String code) =>
      _t('Hauptwährung: $code', 'Main currency: $code');
  String get baseRateNote => _t('Basis (Kurs = 1,00)', 'Base (rate = 1.00)');
  String exchangeRatesIntro(String base) => _t(
    'Lege fest, wie viel 1 Einheit einer Fremdwährung in $base wert ist. Beträge auf Fremdwährungs-Konten werden damit in Summen umgerechnet.',
    'Define how much 1 unit of a foreign currency is worth in $base. Balances on foreign-currency accounts are converted into totals accordingly.',
  );
  String get noForeignCurrencies => _t(
    'Keine Fremdwährungen in Benutzung. Lege ein Konto mit anderer Währung an oder füge unten einen Kurs hinzu.',
    'No foreign currencies in use. Create an account with a different currency or add a rate below.',
  );
  String get noRateSet =>
      _t('Kein Kurs gesetzt (wird 1:1 gerechnet)', 'No rate set (counted 1:1)');
  String get customEllipsis => _t('Eigene…', 'Custom…');

  // ---- Schulden & Kredite ----
  String get noDebtAccounts => _t(
    'Keine Schulden-Konten. Lege ein Konto vom Typ „Kreditkarte" oder „Kredit/Darlehen" an.',
    'No debt accounts. Create an account of type "Credit card" or "Loan".',
  );
  String get creditUtilization =>
      _t('Kreditrahmen-Auslastung', 'Credit limit utilization');
  String get debtTrend12 =>
      _t('Restschuld-Verlauf (12 Monate)', 'Remaining debt trend (12 months)');

  // ---- Export (CSV / PDF) ----
  String get exportTitle => _t('Export (CSV / PDF)', 'Export (CSV / PDF)');
  String exportSubtitle(int n) => _t(
    '$n Buchungen · CSV (Excel/Sheets) oder PDF-Bericht',
    '$n transactions · CSV (Excel/Sheets) or PDF report',
  );
  String get copyCsv => _t('CSV kopieren', 'Copy CSV');
  String get shareCsv => _t('CSV teilen', 'Share CSV');
  String get csvCopied =>
      _t('CSV in Zwischenablage kopiert', 'CSV copied to clipboard');
  String get sharePdf => _t('Als PDF teilen / drucken', 'Share / print as PDF');
  String get previewFirstLines =>
      _t('Vorschau (erste Zeilen):', 'Preview (first lines):');
  String get exportShareText =>
      _t('Money-Manager Export', 'Money Manager export');
  String shareFailed(Object e) => _t(
    'Teilen nicht möglich ($e). Nutze „Kopieren".',
    'Sharing failed ($e). Use "Copy".',
  );
  String pdfStatusLabel(int n, String date) =>
      _t('$n Buchungen · Stand $date', '$n transactions · as of $date');

  // ---- CSV-Import ----
  String get csvImportIntro => _t(
    'Füge hier CSV-Daten ein (Trenner „;" oder „,"). Erwartete Spalten in der Kopfzeile: Datum, Typ, Betrag, Konto, Zielkonto, Kategorie, Titel, Notiz. Konten und Kategorien werden über den Namen zugeordnet (vorher anlegen).',
    'Paste CSV data here (separator ";" or ","). Expected header columns: Datum, Typ, Betrag, Konto, Zielkonto, Kategorie, Titel, Notiz. Accounts and categories are matched by name (create them first).',
  );
  String get importAction => _t('Importieren', 'Import');
  String get importing => _t('Importiere …', 'Importing …');
  String get noLinesDetected =>
      _t('Keine Zeilen erkannt.', 'No lines detected.');
  String get csvHeaderNeeds => _t(
    'Kopfzeile braucht mind. Spalten: Datum, Betrag, Konto.',
    'Header needs at least the columns: Datum, Betrag, Konto.',
  );
  String importResult(int imported, int skipped) => _t(
    '$imported importiert, $skipped übersprungen (kein Konto/Datum/Betrag).',
    '$imported imported, $skipped skipped (missing account/date/amount).',
  );

  // ---- Gemeinsam: Dauerauftrag ----
  String get standingOrderNoun => _t('Dauerauftrag', 'Standing order');

  // ---- Planung (Verfügbar & Fixkosten) ----
  String get availableUntilMonthEnd =>
      _t('Verfügbar bis Monatsende', 'Available until month end');
  String get incomeMonthLabel => _t('Einnahmen (Monat)', 'Income (month)');
  String get minusExpensesSoFar => _t('− Ausgaben bisher', '− expenses so far');
  String get minusOpenFixed => _t('− offene Fixkosten', '− open fixed costs');
  String get projectionMonthEnd =>
      _t('Hochrechnung Monatsende', 'Projection to month end');
  String get expectedExpenses =>
      _t('Ausgaben voraussichtlich', 'Expected expenses');
  String atCurrentPace(int day, int total) => _t(
    'bei aktuellem Tempo (Tag $day von $total)',
    'at current pace (day $day of $total)',
  );
  String vsPrevMonthPct(String pct) =>
      _t('$pct % ggü. Vormonat', '$pct % vs. previous month');
  String get expectedBalance => _t('Voraussichtl. Saldo', 'Expected balance');
  String get fixedCostsMonthly =>
      _t('Fixkosten (monatlich)', 'Fixed costs (monthly)');
  String get noFixedCosts => _t(
    'Keine wiederkehrenden Ausgaben. Lege Daueraufträge unter „Mehr → Daueraufträge" an.',
    'No recurring expenses. Create standing orders under "More → Standing orders".',
  );

  // ---- Cashflow-Kalender ----
  String get currentBalance => _t('Aktueller Kontostand', 'Current balance');
  String get lowestBalance60 =>
      _t('Tiefststand (60 Tage)', 'Lowest point (60 days)');
  String get balanceGoesNegative => _t(
    'Achtung: Der prognostizierte Kontostand wird negativ.',
    'Warning: the projected balance goes negative.',
  );
  String get noPlannedTx60 => _t(
    'Keine geplanten Buchungen in den nächsten 60 Tagen. Lege Daueraufträge unter „Mehr → Daueraufträge" an.',
    'No planned transactions in the next 60 days. Create standing orders under "More → Standing orders".',
  );

  // ---- Was-wäre-wenn (Simulator) ----
  String get simulatorIntro => _t(
    'Passe Einnahmen/Ausgaben an und sieh die Auswirkung auf dein Vermögen in 12 Monaten. (Vorbelegt mit deinen Durchschnitten.)',
    'Adjust income/expenses and see the impact on your net worth in 12 months. (Pre-filled with your averages.)',
  );
  String get incomePerMonth => _t('Einnahmen / Monat', 'Income / month');
  String get expensePerMonth => _t('Ausgaben / Monat', 'Expenses / month');
  String reduceExpenses(int pct) =>
      _t('Ausgaben reduzieren: $pct %', 'Reduce expenses: $pct %');
  String get effectiveExpenses =>
      _t('Effektive Ausgaben', 'Effective expenses');
  String get surplusPerMonth => _t('Überschuss / Monat', 'Surplus / month');
  String get wealthIn12Months =>
      _t('Vermögen in 12 Monaten', 'Net worth in 12 months');
  String wealthChangePrefix(bool positive) => positive
      ? _t('Veränderung: +', 'Change: +')
      : _t('Veränderung: ', 'Change: ');
  String get projection => _t('Projektion', 'Projection');

  // ---- Projekte / Reisen ----
  String get noTagsYet => _t(
    'Noch keine Tags vergeben.\n\nVergib einer Buchung einen Tag (z. B. „Urlaub 2026"), dann erscheint hier die Auswertung dafür.',
    'No tags assigned yet.\n\nAdd a tag to a transaction (e.g. "Vacation 2026"), then the analysis appears here.',
  );

  // ---- Ausgleich (wer schuldet wem) ----
  String get settleTitle => _t('Ausgleich', 'Settle up');
  String get settleNeedsTwo => _t(
    'Für den Ausgleich werden mindestens zwei Personen mit eigenen Konten benötigt.',
    'Settling up requires at least two people with their own accounts.',
  );
  String get sharedExpensesMonth =>
      _t('Geteilte Ausgaben diesen Monat', 'Shared expenses this month');
  String get fairSharePerPerson =>
      _t('Fairer Anteil je Person', 'Fair share per person');
  String get balancesPerPerson => _t('Salden je Person', 'Balances per person');
  String get spentPrefix => _t('ausgegeben ', 'spent ');
  String get settleSuggestion =>
      _t('Ausgleichsvorschlag', 'Settlement suggestion');
  String get allSettled => _t('Alles ausgeglichen 🎉', 'All settled 🎉');
  String get settleHint => _t(
    'Hinweis: Es werden alle Ausgaben des Monats gleichmäßig auf alle Personen aufgeteilt (Haushalts-Modell). Wer mehr bezahlt hat, bekommt etwas zurück.',
    'Note: all of the month\'s expenses are split equally across all people (household model). Whoever paid more gets some back.',
  );

  // ---- Profil ----
  String get profileSaved => _t('Profil gespeichert', 'Profile saved');
  String get displayName => _t('Anzeigename', 'Display name');
  String get signOut => _t('Abmelden', 'Sign out');
  String get customConnectionActive => _t(
    'Eigene (manuell gesetzte) Verbindung aktiv.',
    'Custom (manually set) connection active.',
  );
  String get changeConnection => _t('Verbindung ändern', 'Change connection');

  // ---- Freigaben ----
  String get sharingTitle => _t('Freigaben', 'Sharing');
  String get sharingIntro => _t(
    'Standardmäßig sieht jede Person nur die eigenen Finanzen. Hier gibst du anderen Zugriff:\n• Ansehen: kann deine Konten/Buchungen sehen.\n• Verwalten: darf zusätzlich Buchungen anlegen und ändern.',
    'By default each person only sees their own finances. Here you give others access:\n• View: can see your accounts/transactions.\n• Manage: may also create and edit transactions.',
  );
  String get whoCanAccess => _t(
    'Wer darf auf meine Finanzen zugreifen?',
    'Who may access my finances?',
  );
  String get noOtherPeople => _t(
    'Es sind keine weiteren Personen registriert.',
    'No other people are registered.',
  );
  String get accessNone => _t('Kein', 'None');
  String get accessView => _t('Ansehen', 'View');
  String get accessManage => _t('Verwalten', 'Manage');
  String get whoGrantedMe =>
      _t('Wer hat mir Zugriff gegeben?', 'Who gave me access?');
  String get nobodyGrantedYou => _t(
    'Noch niemand hat dir Zugriff gegeben.',
    'Nobody has given you access yet.',
  );
  String get youMayViewManage =>
      _t('Du darfst ansehen und verwalten', 'You may view and manage');
  String get youMayView => _t('Du darfst ansehen', 'You may view');

  // ---- Dauerauftrag-Formular ----
  String get newRecurring => _t('Neuer Dauerauftrag', 'New standing order');
  String get editRecurring =>
      _t('Dauerauftrag bearbeiten', 'Edit standing order');
  String get deleteRecurringTitle =>
      _t('Dauerauftrag löschen?', 'Delete standing order?');
  String get deleteRecurringBody => _t(
    'Bereits erzeugte Buchungen bleiben erhalten; künftige werden nicht mehr angelegt.',
    'Transactions already created are kept; future ones will no longer be created.',
  );
  String get amountCalcShort =>
      _t('Betrag (auch Rechnung möglich)', 'Amount (math ok)');
  String get recurringTitleHint => _t(
    'Titel (z. B. Miete, Gehalt, Netflix)',
    'Title (e.g. rent, salary, Netflix)',
  );
  String get everyWord => _t('Alle ', 'Every ');
  String get nextDueLabel => _t('Nächste Fälligkeit', 'Next due date');
  String get endDateOptional =>
      _t('Enddatum (optional)', 'End date (optional)');
  String get noEnd => _t('kein Ende', 'no end');

  // ---- Onboarding / Einrichtung ----
  String get onboardingTitle => _t('Einrichtung', 'Setup');
  String get backToChoice => _t('Zurück zur Auswahl', 'Back to selection');
  String get sqlCopied => _t(
    'SQL kopiert. Im Supabase-Dashboard unter „SQL Editor" einfügen und „Run".',
    'SQL copied. Paste it into the "SQL Editor" in the Supabase dashboard and click "Run".',
  );
  String sqlLoadFailed(Object e) =>
      _t('Konnte SQL nicht laden: $e', 'Could not load SQL: $e');
  String get welcomeTitle =>
      _t('Willkommen bei Money Manager', 'Welcome to Money Manager');
  String get welcomeBody => _t(
    'Deine Daten liegen in deinem eigenen, kostenlosen Supabase-Projekt. Wie möchtest du starten?',
    'Your data lives in your own free Supabase project. How would you like to start?',
  );
  String get newInstallTitle => _t('Neue Installation', 'New installation');
  String get newInstallSub => _t(
    'Eigene, leere Datenbank anlegen und einrichten. Die erste Person, die sich registriert, wird Besitzer.',
    'Create and set up your own empty database. The first person to register becomes the owner.',
  );
  String get connectExistingTitle => _t(
    'Mit bestehender Datenbank verbinden',
    'Connect to an existing database',
  );
  String get connectExistingSub => _t(
    'Jemand hat die Datenbank schon eingerichtet. Du gibst nur die Zugangsdaten ein und meldest dich an.',
    'Someone has already set up the database. You just enter the credentials and sign in.',
  );
  String get newOwnDatabase => _t('Neue eigene Datenbank', 'New own database');
  String get connectExistingDb =>
      _t('Bestehende Datenbank verbinden', 'Connect existing database');
  String get step1Title => _t(
    'Kostenloses Supabase-Projekt anlegen',
    'Create a free Supabase project',
  );
  String get step1Body => _t(
    'Gehe auf supabase.com, registriere dich kostenlos und erstelle ein neues Projekt (Region Europa empfohlen). Warte, bis das Projekt fertig eingerichtet ist.',
    'Go to supabase.com, sign up for free and create a new project (Europe region recommended). Wait until the project is fully set up.',
  );
  String get step2Title =>
      _t('Datenbank einrichten (1 Klick)', 'Set up the database (1 click)');
  String get step2Body => _t(
    'Kopiere das vorbereitete SQL, öffne im Supabase-Dashboard den „SQL Editor", füge es ein und klicke „Run". Damit werden alle Tabellen, Sicherheitsregeln und der Beleg-Speicher angelegt.',
    'Copy the prepared SQL, open the "SQL Editor" in the Supabase dashboard, paste it and click "Run". This creates all tables, security rules and the receipt storage.',
  );
  String get copySetupSql => _t('Einrichtungs-SQL kopieren', 'Copy setup SQL');
  String get step3Title => _t('Zugangsdaten eintragen', 'Enter credentials');
  String get existingCredsTitle => _t(
    'Zugangsdaten der bestehenden Datenbank',
    'Credentials of the existing database',
  );
  String get existingCredsBody => _t(
    'Trage die Project-URL und den anon/publishable-Schlüssel der bereits eingerichteten Datenbank ein. Anmelden kannst du dich nur, wenn deine E-Mail dort freigeschaltet ist.',
    'Enter the project URL and the anon/publishable key of the already configured database. You can only sign in if your email is enabled there.',
  );
  String connectionFailed(Object e) =>
      _t('Verbindung fehlgeschlagen: $e', 'Connection failed: $e');
  String get connectAndStart => _t('Verbinden & starten', 'Connect & start');
  String get ownerTip => _t(
    'Tipp: Die erste Person, die sich registriert, wird automatisch Besitzer (Admin mit allen Rechten).',
    'Tip: the first person to register automatically becomes the owner (admin with all rights).',
  );
  String get credentialsIntro => _t(
    'Im Supabase-Dashboard unter „Project Settings" → „Data API" findest du die Project-URL, unter „API Keys" den „anon"/„publishable"-Schlüssel. Beide hier einfügen:',
    'In the Supabase dashboard under "Project Settings" → "Data API" you find the project URL, under "API Keys" the "anon"/"publishable" key. Paste both here:',
  );
  String get supabaseProjectUrl =>
      _t('Supabase Project URL', 'Supabase project URL');
  String get enterUrl => _t('URL eingeben', 'Enter URL');
  String get mustStartHttps =>
      _t('Muss mit https:// beginnen', 'Must start with https://');
  String get anonKeyLabel =>
      _t('anon / publishable Key', 'anon / publishable key');
  String get enterKey => _t('Schlüssel eingeben', 'Enter key');

  // ---- Verbindungs-Editor ----
  String get connectionEditorIntro => _t(
    'Nur ändern, wenn du eine andere Supabase-Datenbank nutzen willst (z. B. weil die URL falsch war). Die Änderung gilt nur auf diesem Gerät.',
    'Only change this if you want to use a different Supabase database (e.g. because the URL was wrong). The change only applies to this device.',
  );
  String get supabaseUrlLabel => _t('Supabase-URL', 'Supabase URL');
  String get resetToDefault =>
      _t('Auf Standard zurücksetzen', 'Reset to default');
  String get disconnect => _t('Verbindung trennen', 'Disconnect');
  String get connectionChanged =>
      _t('Verbindung geändert', 'Connection changed');
  String get connectionChangedBody => _t(
    'Bitte lade die Seite neu (Strg+R) bzw. starte die App neu, damit die neue Verbindung wirksam wird. Deine Daten in Supabase bleiben erhalten.',
    'Please reload the page (Ctrl+R) or restart the app for the new connection to take effect. Your data in Supabase is kept.',
  );
  String get ok => 'OK';

  // ---- App-Sperre (PIN-Eingabe) ----
  String get enterPin => _t('PIN eingeben', 'Enter PIN');
  String get wrongPin => _t('Falsche PIN', 'Wrong PIN');

  // ---- Profil-Wechsler ----
  String get meWord => _t('Ich', 'Me');
  String get personFallback => _t('Person', 'Person');
  String get switchPerson => _t('Person wechseln', 'Switch person');
  String nameWithMe(String name) => _t('$name (ich)', '$name (me)');
  String get allPersons => _t('Alle Personen (gesamt)', 'All people (total)');

  // ---- Kommentare ----
  String get comments => _t('Kommentare', 'Comments');
  String get noComments => _t('Noch keine Kommentare.', 'No comments yet.');
  String get commentHint => _t('Kommentar …', 'Comment …');

  // ---- Verwaltung (Admin) ----
  String get adminTitle => _t('Verwaltung', 'Administration');
  String get noAdminAccess =>
      _t('Kein Zugriff (nur für Admins).', 'No access (admins only).');
  String get allowEmailTitle => _t('E-Mail freischalten', 'Allow email');
  String get emailAddressLabel => _t('E-Mail-Adresse', 'Email address');
  String get allowAction => _t('Freischalten', 'Allow');
  String deleteUserTitle(String name) =>
      _t('Nutzer „$name" löschen?', 'Delete user "$name"?');
  String get deleteUserBody => _t(
    'Das Konto wird dauerhaft entfernt. Erfasste Buchungen/Konten bleiben erhalten (ohne Zuordnung). Das kann nicht rückgängig gemacht werden.',
    'The account is permanently removed. Recorded transactions/accounts are kept (unassigned). This cannot be undone.',
  );
  String get userDeleted => _t('Nutzer gelöscht', 'User deleted');
  String get storageSection => _t('Speicher', 'Storage');
  String get allowedEmailsSection =>
      _t('Freigeschaltete E-Mails', 'Allowed emails');
  String get noAllowedEmails => _t(
    'Noch keine. Nur freigeschaltete E-Mails können sich registrieren (außer dem ersten Konto).',
    'None yet. Only allowed emails can register (except the first account).',
  );
  String get usersSection => _t('Nutzer', 'Users');
  String get dangerZone => _t('Gefahrenzone', 'Danger zone');
  String storageLoadFailed(Object e) => _t(
    'Konnte Speichernutzung nicht laden: $e',
    'Could not load storage usage: $e',
  );
  String get receiptsFiles => _t('Belege / Dateien', 'Receipts / files');
  String sinceDate(String date) => _t('seit $date', 'since $date');
  String get ownerRole => _t('Besitzer', 'Owner');
  String get adminRole => 'Admin';
  String get readOnlyRole => _t('nur Lesen', 'read only');
  String get youRole => _t('du', 'you');
  String get noName => _t('(ohne Name)', '(no name)');
  String get revokeAdmin => _t('Admin-Recht entziehen', 'Revoke admin rights');
  String get makeAdmin => _t('Zum Admin machen', 'Make admin');
  String get grantWrite => _t('Schreibrechte geben', 'Grant write access');
  String get setReadOnlyAction =>
      _t('Auf „nur Lesen" setzen', 'Set to "read only"');
  String get deleteUserAction => _t('Nutzer löschen', 'Delete user');
  String get wipeDbTitle => _t('Datenbank leeren', 'Wipe database');
  String get wipeDbSub => _t(
    'Löscht ALLE Finanzdaten (Buchungen, Konten, Kategorien, Belege …). Nutzer, Rollen und Freischaltungen bleiben erhalten.',
    'Deletes ALL financial data (transactions, accounts, categories, receipts …). Users, roles and allow-list are kept.',
  );
  String get factoryResetTitle =>
      _t('Auf Werkseinstellungen zurücksetzen', 'Reset to factory settings');
  String get factoryResetSub => _t(
    'Löscht ALLES inkl. aller Login-Konten und Freischaltungen. Danach ist die Datenbank im Neuzustand – die nächste Registrierung wird neuer Besitzer. Nur für den Besitzer.',
    'Deletes EVERYTHING including all login accounts and allow-list. Afterwards the database is brand new – the next registration becomes the new owner. Owner only.',
  );
  String get wipeWord => _t('LEEREN', 'WIPE');
  String get wipeConfirmTitle => _t('Datenbank leeren?', 'Wipe database?');
  String wipeConfirmMsg(String word) => _t(
    'Alle Finanzdaten werden unwiderruflich gelöscht. Nutzer bleiben erhalten. Gib zur Bestätigung $word ein.',
    'All financial data is irreversibly deleted. Users are kept. Type $word to confirm.',
  );
  String get dbWiped => _t('Datenbank geleert', 'Database wiped');
  String get dbWipedBody => _t(
    'Alle Daten wurden entfernt. Bitte lade die App neu (Strg+R) bzw. starte sie neu, damit alle Ansichten aktualisiert werden.',
    'All data was removed. Please reload the app (Ctrl+R) or restart it so all views update.',
  );
  String get factoryWord => _t('ZURÜCKSETZEN', 'RESET');
  String get factoryConfirmTitle =>
      _t('Auf Werkseinstellungen zurücksetzen?', 'Reset to factory settings?');
  String factoryConfirmMsg(String word) => _t(
    'ALLES wird gelöscht: alle Daten, alle Nutzer und Freischaltungen. Du wirst danach abgemeldet. Dieser Schritt ist endgültig. Gib zur Bestätigung $word ein.',
    'EVERYTHING is deleted: all data, all users and the allow-list. You will be signed out afterwards. This step is final. Type $word to confirm.',
  );
  String typeWordLabel(String word) => _t('„$word" eingeben', 'Type "$word"');
  String get confirm => _t('Bestätigen', 'Confirm');

  // ---- Backup & Wiederherstellung ----
  String get backupSection => _t('Sicherung', 'Backup');
  String get backupDesc => _t(
    'Exportiert alle Konten, Buchungen, Kategorien, Budgets, Daueraufträge, Sparziele und Vorlagen als JSON-Datei.',
    'Exports all accounts, transactions, categories, budgets, standing orders, savings goals and templates as a JSON file.',
  );
  String get shareSave => _t('Teilen / Speichern', 'Share / save');
  String get copyAction => _t('Kopieren', 'Copy');
  String get restoreSection => _t('Wiederherstellung', 'Restore');
  String get restoreDesc => _t(
    'Spielt ein Backup ein (z. B. in ein leeres Projekt). Vorhandene Einträge mit gleicher ID werden überschrieben; Besitzer werden dem aktuellen Konto zugeordnet.',
    'Restores a backup (e.g. into an empty project). Existing entries with the same ID are overwritten; owners are reassigned to the current account.',
  );
  String get importBackup => _t('Backup importieren', 'Import backup');
  String get pasteBackupJson =>
      _t('Backup-JSON hier einfügen …', 'Paste backup JSON here …');
  String get exporting => _t('Exportiere …', 'Exporting …');
  String get backupShareText =>
      _t('Money-Manager Backup', 'Money Manager backup');
  String get backupCreated => _t('Backup erstellt.', 'Backup created.');
  String exportError(Object e) =>
      _t('Fehler beim Export: $e', 'Export error: $e');
  String get backupCopied =>
      _t('Backup in Zwischenablage kopiert.', 'Backup copied to clipboard.');
  String recordsImported(int n) => _t(
    '$n Datensätze importiert. Bitte App neu starten / Seite neu laden.',
    '$n records imported. Please restart the app / reload the page.',
  );
  String importError(Object e) =>
      _t('Fehler beim Import: $e', 'Import error: $e');

  // ---- Archivierung alter Jahre ----
  String get archiveTitle => _t('Jahre archivieren', 'Archive years');
  String get archiveMenu => _t('Archivierte Jahre', 'Archived years');
  String get archiveAdminEntry =>
      _t('Alte Jahre archivieren', 'Archive old years');
  String get archiveAdminEntrySub => _t(
    'Lagert alte Jahre verschlüsselt nach GitHub aus und gibt Speicher frei.',
    'Moves old years to GitHub (encrypted) and frees up storage.',
  );
  String get archiveIntro => _t(
    'Alte Jahre werden verschlüsselt nach GitHub ausgelagert und danach aus der Datenbank gelöscht. Sie bleiben hier einsehbar, aber schreibgeschützt.',
    'Old years are exported to GitHub (encrypted) and then deleted from the database. They stay viewable here, but read-only.',
  );
  String get archiveWarning => _t(
    'Achtung: Archivierte Jahre lassen sich danach NICHT mehr bearbeiten und fließen NICHT mehr in Statistiken, Budgets oder Auswertungen ein. Nutze das nur, wenn der Speicher fast voll ist.',
    'Warning: archived years can NO LONGER be edited and are NO LONGER included in statistics, budgets or reports. Only use this when storage is nearly full.',
  );
  String get archiveSelectYears =>
      _t('Jahre zum Archivieren wählen', 'Select years to archive');
  String get archiveNoYears =>
      _t('Keine archivierbaren Jahre vorhanden.', 'No archivable years.');
  String archiveTxCount(int n) => _t('$n Buchungen', '$n transactions');
  String get archiveAction => _t('Archivieren', 'Archive');
  String get archiveSelectAtLeastOne => _t(
    'Bitte mindestens ein Jahr wählen.',
    'Please select at least one year.',
  );
  String get archiveConfirmTitle =>
      _t('Ausgewählte Jahre archivieren?', 'Archive selected years?');
  String archiveConfirmBody(String years) => _t(
    'Folgende Jahre werden ausgelagert und aus der Datenbank gelöscht: $years.\n\nDanach sind sie nur noch schreibgeschützt einsehbar und zählen nicht mehr zu Statistik/Budgets.',
    'The following years will be exported and deleted from the database: $years.\n\nAfterwards they are only viewable read-only and no longer count toward statistics/budgets.',
  );
  String get archivedSection => _t('Archivierte Jahre', 'Archived years');
  String get archiveNoneArchived =>
      _t('Noch keine Jahre archiviert.', 'No years archived yet.');
  String get archivedBadge => _t('Archiviert', 'Archived');
  String get archiveView => _t('Ansehen', 'View');
  String get archiveRestore => _t('Zurückholen', 'Restore');
  String archiveRestoreConfirmTitle(int year) =>
      _t('Jahr $year zurückholen?', 'Restore year $year?');
  String get archiveRestoreConfirmBody => _t(
    'Die Buchungen dieses Jahres werden wieder in die Datenbank geschrieben und sind danach wieder bearbeitbar. Der Speicher wird dadurch wieder belegt.',
    "This year's transactions are written back to the database and become editable again. Storage will be used again.",
  );
  String get archiveStepRead => _t('Lese Daten …', 'Reading data …');
  String get archiveStepReceipts => _t('Lade Belege …', 'Loading receipts …');
  String get archiveStepUpload => _t(
    'Lade verschlüsselt nach GitHub …',
    'Uploading to GitHub (encrypted) …',
  );
  String get archiveStepMark => _t('Speichere Marker …', 'Saving marker …');
  String get archiveStepPurge =>
      _t('Gebe Speicher frei …', 'Freeing storage …');
  String archiveDone(int year) =>
      _t('Jahr $year archiviert.', 'Year $year archived.');
  String archiveRestoreDone(int year) =>
      _t('Jahr $year zurückgeholt.', 'Year $year restored.');
  String archiveYearViewTitle(int year) => _t('Archiv $year', 'Archive $year');
  String get archiveReadOnlyNote => _t(
    'Schreibgeschützt – dieses Jahr ist archiviert.',
    'Read-only – this year is archived.',
  );
  String get archiveEmptyYear =>
      _t('Keine Buchungen in diesem Jahr.', 'No transactions in this year.');
  String archiveError(Object e) => _t('Archiv-Fehler: $e', 'Archive error: $e');

  // ---- Archiv-Repo einrichten ----
  String get archiveSetupTitle =>
      _t('Archiv-Repo verbinden', 'Connect archive repo');
  String get archiveSetupIntro => _t(
    'Lege fest, in welches private GitHub-Repo archivierte Jahre verschlüsselt ausgelagert werden. Token und Schlüssel werden serverseitig in Supabase gespeichert – nie im (öffentlichen) Client.',
    'Choose the private GitHub repo where archived years are exported (encrypted). Token and key are stored server-side in Supabase – never in the (public) client.',
  );
  String get archiveRepoLabel =>
      _t('Repo (owner/name oder URL)', 'Repo (owner/name or URL)');
  String get archiveTokenLabel => _t(
    'GitHub-Token (fine-grained, Contents: Read and write)',
    'GitHub token (fine-grained, Contents: Read and write)',
  );
  String get archiveTokenKeepHint => _t(
    'Leer lassen, um das gespeicherte Token zu behalten.',
    'Leave empty to keep the stored token.',
  );
  String get archiveConnect => _t('Verbinden', 'Connect');
  String get archiveSave => _t('Speichern', 'Save');
  String archiveConnectedTo(String repo) =>
      _t('Verbunden mit $repo', 'Connected to $repo');
  String get archiveChange => _t('Repo/Token ändern', 'Change repo/token');
  String get archiveDisconnect => _t('Verbindung trennen', 'Disconnect');
  String get archiveDisconnectConfirmTitle =>
      _t('Verbindung trennen?', 'Disconnect?');
  String get archiveDisconnectConfirmBody => _t(
    'Repo, Token und Schlüssel werden aus Supabase entfernt. Bereits archivierte Dateien bleiben im GitHub-Repo, sind danach aber erst nach erneutem Verbinden (mit demselben Schlüssel) lesbar.',
    'Repo, token and key are removed from Supabase. Already archived files stay in the GitHub repo, but become readable again only after reconnecting (with the same key).',
  );
  String get archiveNotConfigured =>
      _t('Kein Archiv-Repo verbunden.', 'No archive repo connected.');
  String get archiveSetupNeededAdmin => _t(
    'Verbinde zuerst ein privates GitHub-Repo, um Jahre zu archivieren.',
    'Connect a private GitHub repo first to archive years.',
  );
  String get archiveSetupNeededUser => _t(
    'Es ist noch kein Archiv-Repo eingerichtet. Bitte einen Administrator darum bitten.',
    'No archive repo has been set up yet. Please ask an administrator.',
  );
  String get archiveRepoTokenRequired =>
      _t('Bitte Repo und Token angeben.', 'Please provide repo and token.');
  String get archiveConfigSaved =>
      _t('Archiv-Repo gespeichert.', 'Archive repo saved.');
  String get archiveKeyBackupTitle =>
      _t('Schlüssel sichern (wichtig!)', 'Back up your key (important!)');
  String get archiveKeyBackupBody => _t(
    'Dieser Verschlüsselungs-Schlüssel wurde erzeugt und serverseitig gespeichert. Bewahre eine Kopie sicher auf: Geht die Datenbank verloren, sind die archivierten Daten OHNE diesen Schlüssel nicht wiederherstellbar.',
    'This encryption key was generated and stored server-side. Keep a copy somewhere safe: if the database is lost, the archived data CANNOT be recovered without this key.',
  );
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
