// Aufteilung des Gesamtbudgets auf die Kategorie-Budgets.
//
// Beispiel aus der Anforderung: 1000 € Gesamtbudget, 700 € Miete, 200 € Essen.
// Ein weiteres Budget über 200 € (Freizeit) muss eine Warnung auslösen.
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/budget.dart';
import 'package:money_manager/features/budgets/budget_providers.dart';

void main() {
  group('checkAllocation', () {
    const overall = 100000; // 1000 €
    const miete = 70000;
    const essen = 20000;

    test('freies Budget innerhalb des Gesamtbudgets: keine Warnung', () {
      final r = checkAllocation(
        overallCents: overall,
        allocatedOtherCents: miete + essen,
        newCents: 10000, // 100 € -> genau aufgebraucht
      );
      expect(r.exceeds, isFalse);
      expect(r.planned, overall);
      expect(r.overBy, 0);
    });

    test('Überschreitung wird erkannt und beziffert', () {
      final r = checkAllocation(
        overallCents: overall,
        allocatedOtherCents: miete + essen,
        newCents: 20000, // 200 € Freizeit -> 100 € zu viel
      );
      expect(r.exceeds, isTrue);
      expect(r.planned, 110000);
      expect(r.overBy, 10000);
    });

    test(
      'Erhöhen eines bestehenden Budgets rechnet ohne dessen alten Wert',
      () {
        // Essen von 200 € auf 400 € -> verplant 700 + 400 = 1100 €.
        final r = checkAllocation(
          overallCents: overall,
          allocatedOtherCents: miete, // eigenes altes Budget ist abgezogen
          newCents: 40000,
        );
        expect(r.exceeds, isTrue);
        expect(r.overBy, 10000);
      },
    );

    test('ohne Gesamtbudget gibt es keine Obergrenze', () {
      final r = checkAllocation(
        overallCents: null,
        allocatedOtherCents: miete + essen,
        newCents: 500000,
      );
      expect(r.exceeds, isFalse);
      expect(r.overBy, 0);
    });
  });

  group('budgetPeriodWindow', () {
    test('Monat: 1. bis 1. des Folgemonats', () {
      final (start, end) = budgetPeriodWindow(
        BudgetPeriod.month,
        DateTime(2026, 7, 22),
      );
      expect(start, DateTime(2026, 7, 1));
      expect(end, DateTime(2026, 8, 1));
    });

    test('Woche: Montag bis Sonntag', () {
      final (start, end) = budgetPeriodWindow(
        BudgetPeriod.week,
        DateTime(2026, 7, 22), // Mittwoch
      );
      expect(start, DateTime(2026, 7, 20)); // Montag
      expect(end, DateTime(2026, 7, 27));
    });

    test('Woche: Sonntag gehört noch zur laufenden Woche', () {
      final (start, end) = budgetPeriodWindow(
        BudgetPeriod.week,
        DateTime(2026, 7, 26), // Sonntag
      );
      expect(start, DateTime(2026, 7, 20));
      expect(end, DateTime(2026, 7, 27));
    });
  });
}
