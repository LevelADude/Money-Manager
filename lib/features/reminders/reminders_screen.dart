import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'reminders_providers.dart';

/// Erinnerungen: offene Hinweise (fällige Daueraufträge, Budget-Warnungen,
/// Sparziel-Termine) + Erfassungs-Streak.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  Color _color(BuildContext context, ReminderLevel level) => switch (level) {
        ReminderLevel.alert => Colors.red.shade700,
        ReminderLevel.warning => Colors.orange.shade800,
        ReminderLevel.info => Theme.of(context).colorScheme.primary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final streak = ref.watch(streakProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.moreReminders)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: streak.bookedToday
                    ? Colors.green.shade600
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text('🔥', style: const TextStyle(fontSize: 18)),
              ),
              title: Text(l.streakDays(streak.days)),
              subtitle: Text(
                  streak.bookedToday ? l.bookedToday : l.notBookedToday),
              trailing: streak.bookedToday
                  ? null
                  : FilledButton.tonal(
                      onPressed: () => context.go('/transactions/new'),
                      child: Text(l.bookAction),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l.noReminders)),
            )
          else
            for (final r in reminders)
              Card(
                child: ListTile(
                  leading: Icon(r.icon, color: _color(context, r.level)),
                  title: Text(r.title),
                  subtitle: Text(r.subtitle),
                  trailing:
                      r.route == null ? null : const Icon(Icons.chevron_right),
                  onTap: r.route == null ? null : () => context.go(r.route!),
                ),
              ),
        ],
      ),
    );
  }
}
