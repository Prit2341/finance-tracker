import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_tracker/features/accounts/domain/entities/bank_account.dart';
import 'package:finance_tracker/features/accounts/presentation/providers/account_providers.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/features/transactions/presentation/providers/transaction_providers.dart';

class DashboardState {
  final double totalBalance;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double balanceChangePercent;
  final Map<String, double> categoryTotals;
  final List<Transaction> recentTransactions;
  final int anomalyCount;
  final List<BankAccount> accounts;
  final List<BankAccount> lowBalanceAccounts;

  const DashboardState({
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.balanceChangePercent,
    required this.categoryTotals,
    required this.recentTransactions,
    required this.anomalyCount,
    required this.accounts,
    required this.lowBalanceAccounts,
  });

  factory DashboardState.fromData(
    List<Transaction> transactions,
    List<BankAccount> accounts,
  ) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);

    final monthlyTransactions = transactions
        .where((t) => t.date.isAfter(monthStart.subtract(const Duration(days: 1))))
        .toList();

    final prevMonthTransactions = transactions
        .where((t) =>
            t.date.isAfter(prevMonthStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(monthStart))
        .toList();

    final monthlyIncome = monthlyTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final monthlyExpenses = monthlyTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalExpenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    // Use bank account balances if available, else fall back to transaction net
    final accountsTotal =
        accounts.fold(0.0, (sum, a) => sum + a.totalBalance);
    final totalBalance =
        accounts.isNotEmpty ? accountsTotal : (totalIncome - totalExpenses);

    // Compute previous month's net to derive balance change %
    final prevIncome = prevMonthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final prevExpenses = prevMonthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final prevNet = prevIncome - prevExpenses;
    final currentNet = monthlyIncome - monthlyExpenses;
    final balanceChangePercent =
        prevNet.abs() > 0 ? ((currentNet - prevNet) / prevNet.abs()) * 100 : 0.0;

    final categoryTotals = <String, double>{};
    for (final t in monthlyTransactions.where((t) => t.type == TransactionType.expense)) {
      categoryTotals[t.category.name] =
          (categoryTotals[t.category.name] ?? 0) + t.amount;
    }

    final anomalyCount = transactions.where((t) => t.isAnomaly).length;
    final lowBalanceAccounts = accounts
        .where((a) => a.isBelowMinimum || a.isNearMinimum)
        .toList();

    return DashboardState(
      totalBalance: totalBalance,
      monthlyIncome: monthlyIncome,
      monthlyExpenses: monthlyExpenses,
      balanceChangePercent: balanceChangePercent,
      categoryTotals: categoryTotals,
      recentTransactions: transactions.take(5).toList(),
      anomalyCount: anomalyCount,
      accounts: accounts,
      lowBalanceAccounts: lowBalanceAccounts,
    );
  }
}

final dashboardProvider = FutureProvider<DashboardState>((ref) async {
  final transactions = await ref.watch(transactionsProvider.future);
  final accounts = await ref.watch(accountsProvider.future);
  return DashboardState.fromData(transactions, accounts);
});
