import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finance_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:finance_tracker/features/dashboard/presentation/widgets/summary_cards.dart';
import 'package:finance_tracker/features/dashboard/presentation/widgets/category_pie_chart.dart';
import 'package:finance_tracker/features/dashboard/presentation/widgets/spending_chart.dart';
import 'package:finance_tracker/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:finance_tracker/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:finance_tracker/shared/ml/ml_providers.dart';
import 'package:finance_tracker/core/utils/currency_formatter.dart';


class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? (screenWidth - 560) / 2 : 20.0;

    return Scaffold(
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (dashboard) {
          return CustomScrollView(
            slivers: [
              // ─── Header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 16, horizontalPadding, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FINTRACK',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Dashboard Home',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.notifications_none_rounded,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => context.push('/settings'),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: theme.colorScheme.primary,
                            child: Icon(Icons.person,
                                color: theme.colorScheme.onPrimary, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Always show Balance + Income/Expense ────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),

                      // ─── Balance Card ──────────────────────────
                      BalanceCard(
                        totalBalance: dashboard.totalBalance,
                        changePercent: dashboard.balanceChangePercent,
                      ),
                      const SizedBox(height: 16),

                      // ─── Income / Expenses Row ─────────────────
                      IncomeExpenseRow(
                        monthlyIncome: dashboard.monthlyIncome,
                        monthlyExpenses: dashboard.monthlyExpenses,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ─── Empty state or full content ────────────────
              if (dashboard.recentTransactions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first transaction to see analytics',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // ─── Anomaly Alert ─────────────────────────
                        if (dashboard.anomalyCount > 0)
                          _AnomalyAlert(count: dashboard.anomalyCount),
                        if (dashboard.anomalyCount > 0)
                          const SizedBox(height: 16),

                        // ─── 7-Day Forecast ────────────────────────
                        const _ForecastSection(),
                        const SizedBox(height: 16),

                        // ─── Spending Trend (Bar Chart) ────────────
                        const SpendingChart(),
                        const SizedBox(height: 16),

                        // ─── Top Categories Donut Chart ────────────
                        if (dashboard.categoryTotals.isNotEmpty)
                          CategoryPieChart(
                              categoryTotals: dashboard.categoryTotals),
                        if (dashboard.categoryTotals.isNotEmpty)
                          const SizedBox(height: 24),

                        // ─── Recent Transactions Header ────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'RECENT TRANSACTIONS',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/transactions'),
                              child: Text(
                                'See All',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // ─── Recent Transactions List ──────────────────
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final txn = dashboard.recentTransactions[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 4,
                        ),
                        child: TransactionTile(
                          transaction: txn,
                          onTap: () =>
                              context.push('/edit-transaction', extra: txn),
                        ),
                      );
                    },
                    childCount: dashboard.recentTransactions.length,
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─── Anomaly Alert Card ──────────────────────────────────────
class _AnomalyAlert extends StatelessWidget {
  final int count;

  const _AnomalyAlert({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D1B1B)
            : const Color(0xFFFF5252).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF5252).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Color(0xFFFF5252),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anomaly Alert',
                  style: TextStyle(
                    color: const Color(0xFFFF5252),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count unusual transaction${count > 1 ? 's' : ''} detected',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => GoRouter.of(context).go('/analytics'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Resolve',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 7-Day Forecast Section ─────────────────────────────────
class _ForecastSection extends ConsumerWidget {
  const _ForecastSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecasterAsync = ref.watch(forecasterProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final theme = Theme.of(context);

    final forecaster = forecasterAsync.valueOrNull;
    if (forecaster == null) return const SizedBox.shrink();

    final transactions = transactionsAsync.valueOrNull;
    if (transactions == null || transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final result = forecaster.predict(transactions);
    if (result == null) return const SizedBox.shrink();

    // Build day labels starting from tomorrow
    final now = DateTime.now();
    final dayLabels = <String>[];
    final dailyValues = result.dailyPredictions;
    for (int i = 0; i < dailyValues.length && i < 7; i++) {
      final day = now.add(Duration(days: i + 1));
      dayLabels.add(DateFormat('EEE').format(day).toUpperCase());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '7-DAY FORECAST',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'AI PREDICTION',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dailyValues.length.clamp(0, 7),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              // Highlight the first chip (today/tomorrow)
              final isHighlighted = index == 1;
              return _ForecastChip(
                label: index < dayLabels.length ? dayLabels[index] : '—',
                amount: dailyValues[index],
                isHighlighted: isHighlighted,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ForecastChip extends StatelessWidget {
  final String label;
  final double amount;
  final bool isHighlighted;

  const _ForecastChip({
    required this.label,
    required this.amount,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primary
            : isDark
                ? const Color(0xFF1E293B)
                : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: isHighlighted
            ? null
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.08),
              ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isHighlighted
                  ? Colors.white.withValues(alpha: 0.8)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              color: isHighlighted
                  ? Colors.white
                  : theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
