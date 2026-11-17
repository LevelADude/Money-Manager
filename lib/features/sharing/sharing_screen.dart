import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/access_grant.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';
import 'access_grant_providers.dart';
import '../../shared/bento.dart';

/// „Freigaben": legt fest, wer die eigenen Finanzen ansehen/verwalten darf,
/// und zeigt, wer dem aktuellen Nutzer Zugriff gegeben hat.
class SharingScreen extends ConsumerWidget {
  const SharingScreen({super.key});

  /// Ändert eine Freigabe. Kein Optimistic Update: Zugriffsrechte gelten erst,
  /// wenn der Server bestätigt. Schlägt das fehl, bleibt die alte Auswahl
  /// stehen und eine Meldung erklärt warum.
  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    String granteeId,
    String choice,
  ) async {
    final repo = ref.read(accessGrantRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      if (choice == 'none') {
        await repo.revoke(granteeId);
      } else {
        await repo.grant(
          granteeId,
          choice == 'manage' ? GrantLevel.manage : GrantLevel.view,
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorWith(e))));
    } finally {
      ref.invalidate(accessGrantsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider);
    final names =
        ref.watch(profileNamesProvider).value ?? const <String, String>{};
    final iGave = ref.watch(grantsIGaveProvider);
    final iReceived = ref.watch(grantsIReceivedProvider);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    String nameOf(String id) =>
        names[id]?.isNotEmpty == true ? names[id]! : l.unknownPerson;

    final others = names.keys.where((id) => id != myId).toList()
      ..sort(
        (a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()),
      );

    Widget initial(String id) => BentoGlyph(
      size: 38,
      child: Text(
        nameOf(id).isNotEmpty ? nameOf(id)[0].toUpperCase() : '?',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    Widget emptyTile(String text) =>
        BentoTile(child: Text(text, style: Bento.sub(context)));

    return Scaffold(
      appBar: AppBar(title: Text(l.sharingTitle)),
      body: ListView(
        padding: BentoListView.paddingOf(context),
        children: [
          BentoTile(
            child: Row(
              children: [
                const BentoGlyph(child: Icon(Icons.group_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.sharingIntro,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Bento.gap * 2),
          BentoSectionHeader(label: l.whoCanAccess),
          if (others.isEmpty)
            emptyTile(l.noOtherPeople)
          else
            BentoList(
              children: [
                for (final id in others)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BentoRow(
                          padding: EdgeInsets.zero,
                          leading: initial(id),
                          title: Text(nameOf(id)),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: 'none',
                              label: Text(l.accessNone),
                            ),
                            ButtonSegment(
                              value: 'view',
                              label: Text(l.accessView),
                            ),
                            ButtonSegment(
                              value: 'manage',
                              label: Text(l.accessManage),
                            ),
                          ],
                          selected: {
                            switch (iGave[id]) {
                              GrantLevel.manage => 'manage',
                              GrantLevel.view => 'view',
                              null => 'none',
                            },
                          },
                          onSelectionChanged: (s) =>
                              _set(context, ref, id, s.first),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: Bento.gap * 2),
          BentoSectionHeader(label: l.whoGrantedMe),
          if (iReceived.isEmpty)
            emptyTile(l.nobodyGrantedYou)
          else
            BentoList(
              children: [
                for (final e in iReceived.entries)
                  BentoRow(
                    leading: initial(e.key),
                    title: Text(nameOf(e.key)),
                    subtitle: Text(
                      e.value == GrantLevel.manage
                          ? l.youMayViewManage
                          : l.youMayView,
                    ),
                    trailing: Icon(
                      e.value == GrantLevel.manage
                          ? Icons.edit_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
