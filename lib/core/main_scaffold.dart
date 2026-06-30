import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../shared/data_refresh.dart';
import '../shared/responsive.dart';

/// Persistente Menüleiste: untere NavigationBar (schmal/Handy) bzw. seitliche
/// NavigationRail (breit/Desktop). Hält die vier Hauptbereiche. Der Inhalt wird
/// auf breiten Bildschirmen zentriert und in der Breite begrenzt (responsive).
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshAllData(ref);
    }
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
    final items = <({IconData icon, IconData active, String label})>[
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

    // Auf breiten Screens den Inhalt zentriert + begrenzt darstellen.
    final content = MaxWidthBox(child: shell);

    if (context.isWide) {
      final extended = context.isExtraWide;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _goBranch,
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final d in items)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.active),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: [
          for (final d in items)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.active),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
