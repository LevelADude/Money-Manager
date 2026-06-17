import 'package:flutter/material.dart';

/// Bildet die in der DB gespeicherten Icon-Tokens (z. B. 'cart') auf
/// Flutter-Icons ab. Unbekannte Tokens -> neutrales Label-Icon.
IconData iconForToken(String? token) {
  switch (token) {
    case 'cart':
      return Icons.shopping_cart_outlined;
    case 'restaurant':
      return Icons.restaurant_outlined;
    case 'home_supplies':
      return Icons.cleaning_services_outlined;
    case 'home':
      return Icons.home_outlined;
    case 'bolt':
      return Icons.bolt_outlined;
    case 'wifi':
      return Icons.wifi;
    case 'car':
      return Icons.directions_car_outlined;
    case 'bus':
      return Icons.directions_bus_outlined;
    case 'shield':
      return Icons.shield_outlined;
    case 'health':
      return Icons.medical_services_outlined;
    case 'shirt':
      return Icons.checkroom_outlined;
    case 'sports':
      return Icons.sports_esports_outlined;
    case 'subscription':
      return Icons.subscriptions_outlined;
    case 'flight':
      return Icons.flight_outlined;
    case 'gift':
      return Icons.card_giftcard_outlined;
    case 'school':
      return Icons.school_outlined;
    case 'pet':
      return Icons.pets_outlined;
    case 'child':
      return Icons.child_care_outlined;
    case 'donate':
      return Icons.volunteer_activism_outlined;
    case 'tax':
      return Icons.account_balance_outlined;
    case 'savings':
      return Icons.savings_outlined;
    case 'salary':
      return Icons.payments_outlined;
    case 'star':
      return Icons.star_outline;
    case 'work':
      return Icons.work_outline;
    case 'invest':
      return Icons.trending_up;
    case 'refund':
      return Icons.replay_outlined;
    case 'sale':
      return Icons.sell_outlined;
    case 'more':
      return Icons.more_horiz;
    default:
      return Icons.label_outline;
  }
}

/// Icon je Kontotyp-Token (siehe AccountType).
IconData iconForAccountType(String typeToken) {
  switch (typeToken) {
    case 'bank':
      return Icons.account_balance_outlined;
    case 'cash':
      return Icons.payments_outlined;
    case 'credit_card':
      return Icons.credit_card_outlined;
    case 'savings':
      return Icons.savings_outlined;
    case 'loan':
      return Icons.request_quote_outlined;
    case 'investment':
      return Icons.trending_up;
    case 'wallet':
      return Icons.account_balance_wallet_outlined;
    default:
      return Icons.wallet_outlined;
  }
}
