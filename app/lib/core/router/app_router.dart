import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:finance_tracker/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:finance_tracker/features/transactions/presentation/pages/transaction_list_page.dart';
import 'package:finance_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:finance_tracker/features/accounts/presentation/pages/accounts_page.dart';
import 'package:finance_tracker/features/accounts/presentation/pages/add_account_page.dart';
import 'package:finance_tracker/features/analytics/presentation/pages/analytics_page.dart';
import 'package:finance_tracker/features/settings/presentation/pages/settings_page.dart';
import 'package:finance_tracker/features/subscriptions/presentation/pages/subscriptions_page.dart';
import 'package:finance_tracker/features/subscriptions/presentation/pages/add_subscription_page.dart';
import 'package:finance_tracker/features/subscriptions/domain/entities/subscription.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/features/budgets/presentation/pages/budgets_page.dart';
import 'package:finance_tracker/shared/widgets/app_bottom_nav.dart';
import 'package:finance_tracker/features/splash/splash_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

// Tab index mapping for directional transitions
const _tabIndex = {
  '/dashboard': 0,
  '/accounts': 1,
  '/transactions': 2,
  '/analytics': 3,
};

int _previousTabIndex = 0;

Page<void> _buildTabPage({
  required Widget child,
  required String path,
  required LocalKey key,
}) {
  final newIndex = _tabIndex[path] ?? 0;
  final goingForward = newIndex >= _previousTabIndex;
  _previousTabIndex = newIndex;

  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideIn = Tween<Offset>(
        begin: Offset(goingForward ? 1.0 : -1.0, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(goingForward ? -1.0 : 1.0, 0),
      ).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic));

      return SlideTransition(
        position: slideOut,
        child: SlideTransition(
          position: slideIn,
          child: child,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashPage(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppBottomNav(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => _buildTabPage(
            child: const DashboardPage(),
            path: '/dashboard',
            key: state.pageKey,
          ),
        ),
        GoRoute(
          path: '/accounts',
          pageBuilder: (context, state) => _buildTabPage(
            child: const AccountsPage(),
            path: '/accounts',
            key: state.pageKey,
          ),
        ),
        GoRoute(
          path: '/transactions',
          pageBuilder: (context, state) => _buildTabPage(
            child: const TransactionListPage(),
            path: '/transactions',
            key: state.pageKey,
          ),
        ),
        GoRoute(
          path: '/analytics',
          pageBuilder: (context, state) => _buildTabPage(
            child: const AnalyticsPage(),
            path: '/analytics',
            key: state.pageKey,
          ),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add-transaction',
      builder: (context, state) => const AddTransactionPage(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/edit-transaction',
      builder: (context, state) => AddTransactionPage(
        transaction: state.extra as Transaction?,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add-account',
      builder: (context, state) => const AddAccountPage(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/subscriptions',
      builder: (context, state) => const SubscriptionsPage(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add-subscription',
      builder: (context, state) => AddSubscriptionPage(
        subscription: state.extra as Subscription?,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/budgets',
      builder: (context, state) => const BudgetsPage(),
    ),
  ],
);
