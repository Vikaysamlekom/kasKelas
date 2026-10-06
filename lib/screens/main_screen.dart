import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';

/// Halaman utama aplikasi: bottom navigation 4 tab
/// (Dashboard, Siswa, Pembayaran, Lainnya).
class MainScreen extends StatefulWidget {
  final List<Widget> pages;

  const MainScreen({
    super.key,
    required this.pages,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    final int index = context.watch<NavigationProvider>().index;

    return Scaffold(
      body: IndexedStack(index: index, children: widget.pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (int i) {
          context.read<NavigationProvider>().setIndex(i);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Siswa',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Pembayaran',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_rounded),
            label: 'Lainnya',
          ),
        ],
      ),
    );
  }
}