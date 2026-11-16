import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/profile/profile_providers.dart';
import '../features/sharing/access_grant_providers.dart';
import '../features/transactions/person_filter.dart';
import '../l10n/app_localizations.dart';
import '../shared/data_refresh.dart';
import '../shared/glass.dart';
import '../shared/responsive.dart';

/// Persistente Navigation als Glas-Bedienebene: schwebende Pille mit getrenntem
/// Plus-Knopf (schmal/Handy) bzw. schwebende Seitenleiste (breit/Desktop).
/// Hält die vier Hauptbereiche; das Plus legt eine neue Buchung an. Der Inhalt
/// wird auf breiten Bildschirmen zentriert und in der Breite begrenzt.
///
/// Lädt zusätzlich die Daten neu, sobald die App wieder in den Vordergrund
/// kommt (Lifecycle „resumed") – so sind beim Öffnen immer die neuesten Daten da.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Zeitpunkt, an dem die App zuletzt in den Hintergrund ging.
  DateTime? _leftAt;

  /// Erst ab dieser Abwesenheit lohnt ein Neuladen. Kurze Fokuswechsel (Datei-
  /// /Bildauswahl, Tab-Wechsel im Browser, Alt-Tab unter Windows) lösen sonst
  /// mitten im Tippen ein Neuladen aus — genau das soll nicht passieren.
  static const _minAwayForRefresh = Duration(seconds: 20);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final away = _leftAt;
    _leftAt = null;
    if (away == null) return; // nur „inactive" dazwischen → nichts tun
    if (DateTime.now().difference(away) < _minAwayForRefresh) return;
    refreshAllData(ref);
  }

  void _goBranch(int index) {
    widget.shell.goBranch(
      index,
      initialLocation: index == widget.shell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final l = AppLocalizations.of(context);
    final items = <_NavItem>[
      (
        icon: Icons.account_balance_wallet_outlined,
        active: Icons.account_balance_wallet,
        label: l.navAccounts,
      ),
      (
        icon: Icons.receipt_long_outlined,
        active: Icons.receipt_long,
        label: l.navTransactions,
      ),
      (
        icon: Icons.bar_chart_outlined,
        active: Icons.bar_chart,
        label: l.navStatistics,
      ),
      (icon: Icons.menu, active: Icons.menu, label: l.navMore),
    ];

    // Gleiche Regel wie in der Buchungsliste: buchen nur mit Schreibrecht und
    // nur in der Gesamtansicht oder bei Personen, die man verwalten darf.
    final readOnly = ref.watch(isReadOnlyProvider).value ?? false;
    final person = ref.watch(personFilterProvider);
    final canAdd =
        !readOnly &&
        (person == null ||
            ref.watch(manageableOwnersProvider).contains(person));
    final onAdd = canAdd ? () => context.go('/transactions/new') : null;

    // Auf breiten Screens den Inhalt zentriert + begrenzt darstellen.
    // Die Glas-Leiste auch als `viewPadding` melden: verschachtelte Scaffolds
    // richten schwebende Knöpfe und Snackbars daran aus (nicht an `padding`)
    // und lägen sonst hinter der Leiste.
    final content = MaxWidthBox(
      child: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          if (mq.viewPadding.bottom >= mq.padding.bottom) return shell;
          return MediaQuery(
            data: mq.copyWith(
              viewPadding: mq.viewPadding.copyWith(bottom: mq.padding.bottom),
            ),
            child: shell,
          );
        },
      ),
    );

    if (context.isWide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                child: GlassRail(
                  items: items,
                  current: shell.currentIndex,
                  onSelect: _goBranch,
                  onAdd: onAdd,
                  addLabel: l.transactionFab,
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // Inhalt läuft unter der Glas-Leiste durch; Listen hängen den Platz über
      // `withBarInset` / MediaQuery-Padding unten an.
      extendBody: true,
      body: content,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: GlassTabBar(
                items: items,
                current: shell.currentIndex,
                onSelect: _goBranch,
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(width: 12),
              GlassAddButton(onTap: onAdd, label: l.transactionFab),
            ],
          ],
        ),
      ),
    );
  }
}

typedef _NavItem = ({IconData icon, IconData active, String label});

/// Ein Ziel der Navigation: Symbol über kleiner Beschriftung, aktiv getönt.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: selected
                ? scheme.primaryContainer
                : scheme.primaryContainer.withValues(alpha: 0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? item.active : item.icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Schwebende Glas-Pille mit den vier Hauptbereichen (Handy).
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.items,
    required this.current,
    required this.onSelect,
  });

  final List<({IconData icon, IconData active, String label})> items;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Glass(
      borderRadius: const BorderRadius.all(Radius.circular(31)),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavButton(
                item: items[i],
                selected: i == current,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// Runder Plus-Knopf: neue Buchung.
class GlassAddButton extends StatelessWidget {
  const GlassAddButton({super.key, required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: .28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: PressScale(
            shape: const CircleBorder(),
            focusColor: scheme.onPrimary.withValues(alpha: .3),
            onTap: onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(Icons.add, size: 28, color: scheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Schwebende Glas-Seitenleiste (Desktop/Tablet).
class GlassRail extends StatelessWidget {
  const GlassRail({
    super.key,
    required this.items,
    required this.current,
    required this.onSelect,
    required this.onAdd,
    required this.addLabel,
  });

  final List<({IconData icon, IconData active, String label})> items;
  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Glass(
        thick: true,
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: [
            if (onAdd != null) ...[
              GlassAddButton(onTap: onAdd!, label: addLabel),
              const SizedBox(height: 18),
            ],
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: _NavButton(
                    item: items[i],
                    selected: i == current,
                    onTap: () => onSelect(i),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
