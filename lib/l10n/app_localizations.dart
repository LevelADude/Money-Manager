import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
