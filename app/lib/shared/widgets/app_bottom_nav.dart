import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _tabRoutes = ['/dashboard', '/accounts', '/transactions', '/analytics'];

class AppBottomNav extends StatefulWidget {
  final Widget child;

  const AppBottomNav({super.key, required this.child});

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  double _dragStartX = 0;
  bool _swiped = false;
  bool _isEdgeSwipe = false;
  static const _swipeThreshold = 50.0;
  // Only trigger tab swap when drag starts within this margin from screen edge
  static const _edgeMargin = 40.0;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/accounts')) return 1;
    if (location.startsWith('/transactions')) return 2;
    if (location.startsWith('/analytics')) return 3;
    return 0;
  }

  void _navigateToTab(BuildContext context, int index) {
    if (index >= 0 && index < _tabRoutes.length) {
      context.go(_tabRoutes[index]);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    final screenWidth = MediaQuery.of(context).size.width;
    final x = event.position.dx;
    _dragStartX = x;
    _swiped = false;
    _isEdgeSwipe = x <= _edgeMargin || x >= screenWidth - _edgeMargin;
  }

  void _onPointerMove(PointerMoveEvent event, int currentIndex) {
    if (_swiped || !_isEdgeSwipe) return;

    final dx = event.position.dx - _dragStartX;
    // Swipe left (negative dx) → forward (next tab)
    if (dx < -_swipeThreshold && currentIndex < _tabRoutes.length - 1) {
      _swiped = true;
      _navigateToTab(context, currentIndex + 1);
    }
    // Swipe right (positive dx) → backward (previous tab)
    else if (dx > _swipeThreshold && currentIndex > 0) {
      _swiped = true;
      _navigateToTab(context, currentIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: (details) => _onPointerMove(details, index),
        child: widget.child,
      ),
      floatingActionButton: switch (index) {
        0 || 2 => FloatingActionButton(
          onPressed: () => context.push('/add-transaction'),
          child: const Icon(Icons.add),
        ),
        1 => FloatingActionButton(
          onPressed: () => context.push('/add-account'),
          child: const Icon(Icons.add),
        ),
        _ => null,
      },
      bottomNavigationBar: Theme(
        data: theme.copyWith(
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                overflow: TextOverflow.ellipsis,
              );
            }),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => _navigateToTab(context, i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance),
              label: 'Accounts',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Analytics',
            ),
          ],
        ),
      ),
    );
  }
}
