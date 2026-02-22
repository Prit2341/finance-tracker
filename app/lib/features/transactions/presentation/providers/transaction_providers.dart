import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_tracker/features/accounts/presentation/providers/account_providers.dart';
import 'package:finance_tracker/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:finance_tracker/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/features/transactions/domain/repositories/transaction_repository.dart';

final transactionDatasourceProvider = Provider<TransactionLocalDatasource>(
  (ref) => TransactionLocalDatasource(),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepositoryImpl(ref.watch(transactionDatasourceProvider)),
);

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() async {
    final repo = ref.watch(transactionRepositoryProvider);
    return repo.getAll();
  }

  Future<void> add(Transaction transaction) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.add(transaction);
    await _adjustAccountBalance(transaction);
    ref.invalidateSelf();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.update(transaction);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final repo = ref.read(transactionRepositoryProvider);
    // Get transaction before deleting to reverse the balance
    final transactions = state.valueOrNull ?? [];
    final transaction = transactions.where((t) => t.id == id).firstOrNull;
    await repo.delete(id);
    if (transaction != null) {
      await _reverseAccountBalance(transaction);
    }
    ref.invalidateSelf();
  }

  Future<void> _adjustAccountBalance(Transaction transaction) async {
    if (transaction.accountId == null) return;
    final accountRepo = ref.read(accountRepositoryProvider);
    final account = await accountRepo.getById(transaction.accountId!);
    if (account == null) return;

    final delta = transaction.type == TransactionType.expense
        ? -transaction.amount
        : transaction.amount;
    await accountRepo.update(account.copyWith(
      usableAmount: account.usableAmount + delta,
      totalBalance: account.totalBalance + delta,
      updatedAt: DateTime.now(),
    ));
    ref.invalidate(accountsProvider);
  }

  Future<void> _reverseAccountBalance(Transaction transaction) async {
    if (transaction.accountId == null) return;
    final accountRepo = ref.read(accountRepositoryProvider);
    final account = await accountRepo.getById(transaction.accountId!);
    if (account == null) return;

    final delta = transaction.type == TransactionType.expense
        ? transaction.amount
        : -transaction.amount;
    await accountRepo.update(account.copyWith(
      usableAmount: account.usableAmount + delta,
      totalBalance: account.totalBalance + delta,
      updatedAt: DateTime.now(),
    ));
    ref.invalidate(accountsProvider);
  }
}
