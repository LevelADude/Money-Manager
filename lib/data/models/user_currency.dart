/// Eine Währung eines Besitzers samt Wechselkurs, siehe Tabelle `currencies`.
///
/// [rateToBase] ist die Anzahl Einheiten der **Basiswährung des Besitzers** je
/// 1 Einheit von [code] (`null` = noch kein Kurs gesetzt).
class UserCurrency {
  const UserCurrency({
    required this.ownerId,
    required this.code,
    required this.rateToBase,
  });

  final String ownerId;
  final String code;
  final double? rateToBase;

  factory UserCurrency.fromJson(Map<String, dynamic> json) => UserCurrency(
    ownerId: json['owner_id'] as String,
    code: json['code'] as String,
    rateToBase: (json['rate_to_base'] as num?)?.toDouble(),
  );
}
