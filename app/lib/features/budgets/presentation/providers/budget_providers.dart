import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_tracker/features/budgets/data/datasources/budget_local_datasource.dart';
import 'package:finance_tracker/features/budgets/domain/entities/budget.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/features/transactions/presentation/providers/transaction_providers.dart';

final budgetDatasourceProvider = Provider<BudgetLocalDatasource>(
  (ref) => BudgetLocalDatasource(),
);

final budgetsProvider =
    AsyncNotifierProvider<BudgetsNotifier, List<Budget>>(BudgetsNotifier.new);

class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() async {
    final ds = ref.watch(budgetDatasourceProvider);
    return ds.getAll();
  }

  Future<void> add(Budget budget) async {
    final ds = ref.read(budgetDatasourceProvider);
    await ds.insert(budget);
    ref.invalidateSelf();
  }

  Future<void> updateBudget(Budget budget) async {
    final ds = ref.read(budgetDatasourceProvider);
    await ds.update(budget);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final ds = ref.read(budgetDatasourceProvider);
    await ds.delete(id);
    ref.invalidateSelf();
  }
}

/// Computes spent amount per category for the current month
final monthlySpendingByCategoryProvider =
    Provider<Map<TransactionCategory, double>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  final transactions = transactionsAsync.valueOrNull ?? [];

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  final spending = <TransactionCategory, double>{};
  for (final txn in transactions) {
    if (txn.type == TransactionType.expense &&
        !txn.date.isBefore(monthStart)) {
      spending[txn.category] = (spending[txn.category] ?? 0) + txn.amount;
    }
  }
  return spending;
});

/// Total budget limit across all categories
final totalBudgetLimitProvider = Provider<double>((ref) {
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
  return budgets.fold(0.0, (sum, b) => sum + b.limit);
});

/// Total spent across budgeted categories this month
final totalBudgetSpentProvider = Provider<double>((ref) {
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
  final spending = ref.watch(monthlySpendingByCategoryProvider);
  double total = 0;
  for (final b in budgets) {
    total += spending[b.category] ?? 0;
  }
  return total;
});
