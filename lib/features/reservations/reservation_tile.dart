import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/reservation.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import 'redeem_reservation_sheet.dart';
import 'reservation_providers.dart';

/// Eine Reservierung in einer Liste: Name, Betrag, Fälligkeit/Rhythmus und
/// Aktionen (Einlösen, Bearbeiten, Löschen).
class ReservationTile extends ConsumerWidget {
  const ReservationTile({
    super.key,
    required this.reservation,
    required this.currency,
    required this.canManage,
    required this.onEdit,
    this.accountName,
  });

  final Reservation reservation;
  final String currency;
  final bool canManage;
  final VoidCallback onEdit;

  /// Kontoname (nur in der kontoübergreifenden Übersicht).
  final String? accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final r = reservation;
    final df = DateFormat('dd.MM.yyyy');
    final now = DateTime.now();
    final days = r.daysUntilDue(now);
    final dueColor = days == null
        ? null
        : days < 0
        ? Colors.red.shade700
        : days <= 3
        ? Colors.orange.shade800
        : null;

    final parts = <String>[
      ?accountName,
      if (r.dueOn != null) l.dueOnShort(df.format(r.dueOn!)),
      if (r.isRecurring)
        l.topupSummary(
          formatMoney(r.topupCents!, currency),
          l.topupUnitSingular(r.topupUnit!),
        ),
      if (r.isRecurring)
        r.nextTopup == null
            ? l.targetReached
            : l.nextTopupOn(df.format(r.nextTopup!)),
    ];

    return ListTile(
      onTap: canManage ? onEdit : null,
      leading: CircleAvatar(
        backgroundColor: (dueColor ?? Theme.of(context).colorScheme.primary)
            .withValues(alpha: 0.15),
        child: Icon(
          r.isRecurring ? Icons.autorenew : Icons.bookmark_outline,
          color: dueColor ?? Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(r.name, overflow: TextOverflow.ellipsis),
      subtitle: parts.isEmpty
          ? null
          : Text(
              parts.join('  ·  '),
              style: dueColor == null ? null : TextStyle(color: dueColor),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(
            r.amountCents,
            currency: currency,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (canManage)
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'redeem':
                    await showRedeemReservationSheet(context, r);
                  case 'edit':
                    onEdit();
                  case 'delete':
                    await confirmDeleteReservation(context, ref, r);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'redeem',
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag_outlined),
                    title: Text(l.redeemAction),
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(l.edit),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text(l.delete),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Fragt nach und löscht die Reservierung (Betrag wird freigegeben, keine
/// Buchung).
Future<void> confirmDeleteReservation(
  BuildContext context,
  WidgetRef ref,
  Reservation r,
) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.deleteReservationTitle(r.name)),
      content: Text(l.deleteReservationBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.delete),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(reservationRepositoryProvider).delete(r.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.reservationDeleted)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.errorWith(e))));
    }
  }
}
