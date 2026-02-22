import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:finance_tracker/shared/ml/ml_providers.dart';
import 'package:finance_tracker/core/constants/app_constants.dart';
import 'package:finance_tracker/core/utils/currency_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:finance_tracker/shared/ml/savings_advisor.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Insights'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => context.push('/settings'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(Icons.person, size: 20, color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Anomalies', icon: Icon(Icons.warning_amber_rounded)),
            Tab(text: 'Forecast', icon: Icon(Icons.show_chart_rounded)),
            Tab(text: 'Savings', icon: Icon(Icons.savings_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AnomalyTab(),
          _ForecastTab(),
          _SavingsTab(),
        ],
      ),
    );
  }
}

// ─── Anomaly Tab ───────────────────────────────────────────

class _AnomalyTab extends ConsumerWidget {
  const _AnomalyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final detectorAsync = ref.watch(anomalyDetectorProvider);
    final theme = Theme.of(context);
    final hasDetector = detectorAsync.valueOrNull != null;

    return transactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (transactions) {
        final anomalies = transactions.where((t) => t.isAnomaly).toList();
        final recentTransactions = transactions.take(50).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Status Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: anomalies.isNotEmpty
                              ? [theme.colorScheme.error, theme.colorScheme.errorContainer]
                              : [const Color(0xFF4CAF50), const Color(0xFF81C784)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: (anomalies.isNotEmpty ? theme.colorScheme.error : const Color(0xFF4CAF50))
                                .withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              anomalies.isNotEmpty ? Icons.warning_rounded : Icons.verified_user_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  anomalies.isNotEmpty ? 'Anomalies Detected' : 'All Clear',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  anomalies.isNotEmpty
                                      ? '${anomalies.length} suspicious transactions found'
                                      : 'No anomalies detected recently',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (!hasDetector)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.model_training, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('Model Not Ready', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Train the anomaly detector in Settings',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (anomalies.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Recent Alerts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final t = anomalies[index];
                      return _AnomalyListTile(transaction: t);
                    },
                    childCount: anomalies.length,
                  ),
                ),
              ),
            ] else ...[
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Your spending looks normal',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            if (recentTransactions.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Score Analysis',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold),
                      ),
                       Tooltip(
                        message: 'Higher scores indicate unusual behavior',
                        child: Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final t = recentTransactions[index];
                    return _TransactionScoreTile(transaction: t);
                  },
                  childCount: recentTransactions.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        );
      },
    );
  }
}

class _AnomalyListTile extends StatelessWidget {
  final Transaction transaction;

  const _AnomalyListTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = transaction.type == TransactionType.expense;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_rounded,
            color: theme.colorScheme.error,
            size: 24,
          ),
        ),
        title: Text(
          transaction.merchant,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(AppConstants.categoryIcons[transaction.category], size: 12, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  transaction.category.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat.MMMd().format(transaction.date),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
            if (transaction.anomalyScore != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Score: ${transaction.anomalyScore!.toStringAsFixed(4)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: Text(
          '${isExpense ? "-" : "+"}${CurrencyFormatter.format(transaction.amount)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _TransactionScoreTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionScoreTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = transaction.anomalyScore ?? 0.0;
    final isAnomaly = transaction.isAnomaly;

    return Column(
      children: [
        ListTile(
          dense: true,
          leading: Icon(
            AppConstants.categoryIcons[transaction.category],
            color: isAnomaly
                ? theme.colorScheme.error
                : AppConstants.categoryColors[transaction.category],
            size: 20,
          ),
          title: Text(
            transaction.merchant,
            style: theme.textTheme.bodyMedium,
          ),
          trailing: Container(
            width: 80,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (score * 10).clamp(0.0, 1.0), // Visualize score
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: isAnomaly ? theme.colorScheme.error : theme.colorScheme.primary,
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  score.toStringAsFixed(3),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isAnomaly ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'SpaceGrotesk',
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, indent: 56, endIndent: 16, color: theme.dividerColor.withValues(alpha: 0.1)),
      ],
    );
  }
}

// ─── Placeholder Tabs ──────────────────────────────────────

// ─── Forecast Tab ───────────────────────────────────────────

class _ForecastTab extends ConsumerWidget {
  const _ForecastTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecasterAsync = ref.watch(forecasterProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final theme = Theme.of(context);

    final forecaster = forecasterAsync.valueOrNull;
    if (forecaster == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_graph_rounded, size: 64, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Forecast Unavailable', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Train the forecasting model in Settings',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return transactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (transactions) {
        final result = forecaster.predict(transactions);

        if (result == null) {
          final oldestDate = transactions.isEmpty
              ? null
              : transactions
                  .map((t) => t.date)
                  .reduce((a, b) => a.isBefore(b) ? a : b);
          final daysCovered = oldestDate != null
              ? DateTime.now().difference(oldestDate).inDays
              : 0;
          final daysNeeded = forecaster.lookback - daysCovered;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_bottom_rounded,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text('Gathering Data...', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  Text(
                    'We need ${forecaster.lookback} days of history to generate accurate forecasts.\n'
                    'You have $daysCovered days.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  LinearProgressIndicator(
                    value: (daysCovered / forecaster.lookback).clamp(0.0, 1.0),
                    borderRadius: BorderRadius.circular(8),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${daysNeeded > 0 ? daysNeeded : 0} more days needed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final predictions = result.dailyPredictions;
        final now = DateTime.now();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Forecast Highlights
             Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.date_range, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Next 7 Days',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Predicted',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(result.totalPredicted),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'SpaceGrotesk',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(result.averageDaily),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'SpaceGrotesk',
                            ),
                          ),
                          Text(
                            'daily avg',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Bar chart
            Text('Spending Trend', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: predictions.reduce((a, b) => a > b ? a : b) * 1.2,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final date = now.add(Duration(days: value.toInt() + 1));
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              DateFormat.E().format(date)[0],
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: List.generate(predictions.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: predictions[i],
                          color: theme.colorScheme.primary,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: predictions.reduce((a, b) => a > b ? a : b) * 1.2,
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Daily breakdown
            Text('Daily Breakdown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...List.generate(predictions.length, (i) {
              final date = now.add(Duration(days: i + 1));
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat.d().format(date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Text(DateFormat.EEEE().format(date)),
                  trailing: Text(
                    CurrencyFormatter.format(predictions[i]),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 48),
          ],
        );
      },
    );
  }
}

// ─── Savings Tab ───────────────────────────────────────────

class _SavingsTab extends ConsumerWidget {
  const _SavingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advisorAsync = ref.watch(savingsAdvisorProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final theme = Theme.of(context);

    final advisor = advisorAsync.valueOrNull;
    if (advisor == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings_rounded, size: 64, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Advisor Unavailable', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add recommendation templates in code',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return transactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (transactions) {
        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded, size: 64, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('No Spending Data', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Make transactions to reveal savings opportunities',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        final analysis = advisor.analyze(transactions);

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Risk card
            _RiskCard(analysis: analysis),
            const SizedBox(height: 24),

            // Savings Rate
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Savings Rate', style: theme.textTheme.titleMedium),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(analysis.savingsRate * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: analysis.savingsRate.clamp(0.0, 1.0),
                      minHeight: 12,
                      backgroundColor: theme.colorScheme.surface,
                      color: analysis.savingsRate > 0.2
                          ? Colors.green
                          : analysis.savingsRate > 0.05
                              ? Colors.orange
                              : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'of your income saved this month',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Recommendations
            Text('Smart Recommendations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (analysis.recommendations.isNotEmpty)
              ...analysis.recommendations.map((rec) => _RecommendationCard(recommendation: rec))
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'You are doing great! No specific improvements found right now.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
             const SizedBox(height: 48),
          ],
        );
      },
    );
  }
}

class _RiskCard extends StatelessWidget {
  final SavingsAnalysis analysis;

  const _RiskCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color riskColor;
    final IconData riskIcon;
    final String title;
    
    switch (analysis.risk) {
      case SpendingRisk.healthy:
        riskColor = Colors.green;
        riskIcon = Icons.health_and_safety_rounded;
        title = "Financial Health: Excellent";
      case SpendingRisk.moderate:
        riskColor = Colors.orange;
        riskIcon = Icons.warning_amber_rounded;
        title = "Financial Health: Moderate";
      case SpendingRisk.atRisk:
        riskColor = theme.colorScheme.error;
        riskIcon = Icons.dangerous_rounded;
        title = "Financial Health: At Risk";
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(riskIcon, size: 32, color: riskColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            analysis.riskDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final SavingsRecommendation recommendation;

  const _RecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color priorityColor;
    switch (recommendation.priority) {
      case 'critical':
        priorityColor = theme.colorScheme.error;
      case 'high':
        priorityColor = Colors.orange;
      case 'medium':
        priorityColor = Colors.amber;
      default:
        priorityColor = theme.colorScheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: priorityColor),
                const SizedBox(width: 8),
                Text(
                  recommendation.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: priorityColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (recommendation.potentialSavings != null)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: Colors.white.withValues(alpha: 0.5),
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Text(
                     'Save ${(recommendation.potentialSavings! * 100).toStringAsFixed(0)}%',
                     style: theme.textTheme.labelSmall?.copyWith(
                       color: priorityColor,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                 ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              recommendation.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
