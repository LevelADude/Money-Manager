import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../transactions/transaction_providers.dart';

/// Schulden-/Kredit-Tracker: Restschuld + Verlauf je Verbindlichkeits-Konto
/// (Kreditkarte / Kredit), inkl. Kreditrahmen-Auslastung.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final txs = ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final liabilities =
        accounts.where((a) => a.type.isLiability && !a.archived).toList();

    final totalDebt = liabilities.fold<int>(0, (s, a) {
      var b = a.openingBalanceCents;
      for (final t in txs) {
        b += t.signedCentsFor(a.id);
      }
      return s + (b < 0 ? -b : 0);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Schulden & Kredite')),
      body: liabilities.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Keine Schulden-Konten. Lege ein Konto vom Typ '
                    '„Kreditkarte" oder „Kredit/Darlehen" an.'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.trending_down),
                    title: const Text('Schulden gesamt'),
                    trailing: MoneyText(totalDebt,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: totalDebt > 0 ? Colors.red.shade700 : null)),
                  ),
                ),
                const SizedBox(height: 8),
                for (final a in liabilities) _DebtCard(account: a, txs: txs),
              ],
            ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.account, required this.txs});

  final Account account;
  final List<AppTransaction> txs;

  @override
  Widget build(BuildContext context) {
    // Aktueller Saldo (negativ = Schuld).
    var current = account.openingBalanceCents;
    for (final t in txs) {
      current += t.signedCentsFor(account.id);
    }
    final debt = current < 0 ? -current : 0;

    // Restschuld-Verlauf: Saldo zum Monatsende der letzten 12 Monate.
    final now = DateTime.now();
    final series = <int>[];
    for (var i = 11; i >= 0; i--) {
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);
      var b = account.openingBalanceCents;
      for (final t in txs) {
        if (!t.occurredOn.isAfter(monthEnd)) b += t.signedCentsFor(account.id);
      }
      series.add(b);
    }

    final limit = account.creditLimitCents;
    final utilization = (limit != null && limit > 0)
        ? (debt / limit).clamp(0.0, 1.0)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(account.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                MoneyText(
                  current,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: current < 0 ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),
            if (utilization != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: utilization,
                  minHeight: 8,
                  color: utilization >= 0.9
                      ? Colors.red.shade600
                      : Colors.orange.shade700,
                  backgroundColor: Colors.orange.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kreditrahmen-Auslastung',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('${(utilization * 100).round()} %',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text('Restschuld-Verlauf (12 Monate)',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            SizedBox(
              height: 80,
              child: CustomPaint(
                size: Size.infinite,
                painter: _LinePainter(
                  values: series,
                  lineColor: Theme.of(context).colorScheme.primary,
                  gridColor: Theme.of(context).dividerColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  final List<int> values;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV) == 0 ? 1 : (maxV - minV);
    double x(int i) => size.width * i / (values.length - 1);
    double y(int v) => size.height - (v - minV) / range * size.height;

    // Null-Linie, falls der Bereich die Null kreuzt.
    if (minV < 0 && maxV > 0) {
      final zy = y(0);
      canvas.drawLine(
        Offset(0, zy),
        Offset(size.width, zy),
        Paint()
          ..color = gridColor
          ..strokeWidth = 1,
      );
    }

    final path = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}
