/// Kontotyp. `credit_card`/`loan` sind Verbindlichkeiten (Saldo kann negativ
/// = Schuld sein).
enum AccountType { bank, cash, creditCard, savings, loan, investment, wallet, other }

AccountType accountTypeFromDb(String s) => switch (s) {
      'bank' => AccountType.bank,
      'cash' => AccountType.cash,
      'credit_card' => AccountType.creditCard,
      'savings' => AccountType.savings,
      'loan' => AccountType.loan,
      'investment' => AccountType.investment,
      'wallet' => AccountType.wallet,
      _ => AccountType.other,
    };

String accountTypeToDb(AccountType t) => switch (t) {
      AccountType.bank => 'bank',
      AccountType.cash => 'cash',
      AccountType.creditCard => 'credit_card',
      AccountType.savings => 'savings',
      AccountType.loan => 'loan',
      AccountType.investment => 'investment',
      AccountType.wallet => 'wallet',
      AccountType.other => 'other',
    };

extension AccountTypeX on AccountType {
  String get label => switch (this) {
        AccountType.bank => 'Bankkonto',
        AccountType.cash => 'Bargeld',
        AccountType.creditCard => 'Kreditkarte',
        AccountType.savings => 'Sparkonto',
        AccountType.loan => 'Kredit / Darlehen',
        AccountType.investment => 'Depot / Investment',
        AccountType.wallet => 'E-Wallet',
        AccountType.other => 'Sonstiges',
      };

  /// Verbindlichkeit (Schuld) statt Vermögenswert?
  bool get isLiability =>
      this == AccountType.creditCard || this == AccountType.loan;
}

/// Ein Konto, siehe Tabelle `accounts`.
class Account {
  const Account({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalanceCents,
    required this.icon,
    required this.color,
    required this.creditLimitCents,
    required this.includeInNetWorth,
    required this.archived,
    this.sortOrder = 0,
  });

  final String id;
  final String? ownerId;
  final String name;
  final AccountType type;
  final String currency;
  final int openingBalanceCents;
  final String? icon;
  final int? color;
  final int? creditLimitCents;
  final bool includeInNetWorth;
  final bool archived;
  final int sortOrder;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String?,
        name: json['name'] as String,
        type: accountTypeFromDb((json['type'] as String?) ?? 'other'),
        currency: (json['currency'] as String?) ?? 'EUR',
        openingBalanceCents: (json['opening_balance_cents'] as num?)?.toInt() ?? 0,
        icon: json['icon'] as String?,
        color: (json['color'] as num?)?.toInt(),
        creditLimitCents: (json['credit_limit_cents'] as num?)?.toInt(),
        includeInNetWorth: (json['include_in_net_worth'] as bool?) ?? true,
        archived: (json['archived'] as bool?) ?? false,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}
