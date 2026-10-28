import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';

/// Halaman utama aplikasi: bottom navigation 4 tab
/// (Dashboard, Siswa, Pembayaran, Lainnya).
class MainScreen extends StatefulWidget {
  final List<Widget> pages;

  const MainScreen({super.key, required this.pages});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final NavigationProvider _navigation;
  late final PageController _pageController;
  int? _programmaticTarget;

  @override
  void initState() {
    super.initState();
    _navigation = context.read<NavigationProvider>();
    _navigation.addListener(_handleNavigationChanged);
    _pageController = PageController(initialPage: _navigation.index);
  }

  @override
  void dispose() {
    _navigation.removeListener(_handleNavigationChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _handleNavigationChanged() {
    if (!mounted) return;

    final int index = _navigation.index;
    if (_programmaticTarget == index ||
        (_pageController.hasClients &&
            _pageController.page?.round() == index)) {
      setState(() {});
      return;
    }

    _programmaticTarget = index;
    setState(() {});
    _animateToPage(index);
  }

  void _animateToPage(int index) {
    if (!_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _programmaticTarget == index) {
          _animateToPage(index);
        }
      });
      return;
    }

    unawaited(
      _pageController
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted && _programmaticTarget == index) {
              _programmaticTarget = null;
            }
          }),
    );
  }

  void _selectPage(int index) {
    if (_navigation.index == index) return;
    _programmaticTarget = index;
    _navigation.setIndex(index);
    _animateToPage(index);
  }

  void _handlePageChanged(int index) {
    if (_programmaticTarget != null) return;
    _navigation.setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final int index = _navigation.index;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _handlePageChanged,
        children: <Widget>[
          for (int i = 0; i < widget.pages.length; i++)
            _KeepAlivePage(key: ValueKey<int>(i), child: widget.pages[i]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _selectPage,
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
          NavigationDestination(icon: Icon(Icons.apps_rounded), label: 'Lainnya'),
        ],
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
