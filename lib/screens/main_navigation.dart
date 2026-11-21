import 'package:flutter/material.dart';

import 'analytics_page.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;

  static const List<Widget> _pages = [
    DashboardPage(),
    AnalyticsPage(),
    HistoryPage(),
    SettingsPage(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights_rounded),
      label: 'Analitik',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history_rounded),
      label: 'Riwayat',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Pengaturan',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final isExtended = constraints.maxWidth >= 1100;

        if (!isWide) {
          return Scaffold(
            body: IndexedStack(
              index: selectedIndex,
              children: _pages,
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
              destinations: _destinations,
              height: 72,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              Container(
                color: const Color(0xFFF8FAFC),
                child: SafeArea(
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() => selectedIndex = index);
                    },
                    extended: isExtended,
                    labelType: NavigationRailLabelType.all,
                    minWidth: 78,
                    minExtendedWidth: 216,
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 20, 12, 28),
                      child: isExtended
                          ? Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF175CD3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.storefront_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Smart Customer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Color(0xFF172B4D),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF175CD3),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard_rounded),
                        label: Text('Dashboard'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.insights_outlined),
                        selectedIcon: Icon(Icons.insights_rounded),
                        label: Text('Analitik'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history_rounded),
                        label: Text('Riwayat'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings_rounded),
                        label: Text('Pengaturan'),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
