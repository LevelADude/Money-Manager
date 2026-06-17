import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Persistente Menüleiste: untere NavigationBar (schmal/Handy) bzw. seitliche
/// NavigationRail (breit/Desktop). Hält die vier Hauptbereiche.
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _goBranch(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, IconData active, String label})>[
      (
        icon: Icons.account_balance_wallet_outlined,
        active: Icons.account_balance_wallet,
        label: 'Konten'
      ),
      (
        icon: Icons.receipt_long_outlined,
        active: Icons.receipt_long,
        label: 'Buchungen'
      ),
      (icon: Icons.bar_chart_outlined, active: Icons.bar_chart, label: 'Statistik'),
      (icon: Icons.menu, active: Icons.menu, label: 'Mehr'),
    ];

    final wide = MediaQuery.sizeOf(context).width >= 640;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _goBranch,
              labelType: NavigationRailLabelType.all,
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
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
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
