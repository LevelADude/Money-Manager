import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'reminders_providers.dart';
import '../../core/theme.dart';
import '../../shared/bento.dart';

/// Erinnerungen: offene Hinweise (fällige Daueraufträge, Budget-Warnungen,
/// Sparziel-Termine) + Erfassungs-Streak.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  Color _color(BuildContext context, ReminderLevel level) => switch (level) {
    ReminderLevel.alert => AppColors.of(context).expense,
    ReminderLevel.warning => AppColors.of(context).warning,
    ReminderLevel.info => Theme.of(context).colorScheme.primary,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final streak = ref.watch(streakProvider);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ink2 = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text(l.moreReminders)),
      body: ListView(
        padding: BentoListView.paddingOf(context),
        children: [
          BentoTile(
            child: Row(
              children: [
                BentoGlyph(
                  tint: streak.bookedToday
                      ? AppColors.of(context).income
                      : null,
                  child: const Text('🔥', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.streakDays(streak.days),
                        style: Bento.number(context, size: 18),
                      ),
                      Text(
                        streak.bookedToday ? l.bookedToday : l.notBookedToday,
                        style: Bento.sub(context),
                      ),
                    ],
                  ),
                ),
                if (!streak.bookedToday) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => context.go('/transactions/new'),
                    child: Text(l.bookAction),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Bento.gap),
          if (reminders.isEmpty)
            BentoTile(
              child: Row(
                children: [
                  BentoGlyph(
                    size: 38,
                    tint: AppColors.of(context).income,
                    child: const Icon(Icons.check),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.noReminders,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            BentoList(
              children: [
                for (final r in reminders)
                  BentoRow(
                    leading: BentoGlyph(
                      size: 38,
                      tint: _color(context, r.level),
                      child: Icon(r.icon),
                    ),
                    title: Text(r.title),
                    subtitle: Text(r.subtitle),
                    subtitleMaxLines: 3,
                    trailing: r.route == null
                        ? null
                        : Icon(Icons.chevron_right, size: 20, color: ink2),
                    onTap: r.route == null ? null : () => context.go(r.route!),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
