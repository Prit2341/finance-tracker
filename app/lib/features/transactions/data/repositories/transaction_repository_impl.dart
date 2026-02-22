import 'package:finance_tracker/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/features/transactions/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDatasource _datasource;

  TransactionRepositoryImpl(this._datasource);

  @override
  Future<List<Transaction>> getAll() => _datasource.getAll();

  @override
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end) =>
      _datasource.getByDateRange(start, end);

  @override
  Future<List<Transaction>> getByCategory(TransactionCategory category) =>
      _datasource.getByCategory(category);

  @override
  Future<void> add(Transaction transaction) => _datasource.insert(transaction);

  @override
  Future<void> update(Transaction transaction) =>
      _datasource.update(transaction);

  @override
  Future<void> delete(String id) => _datasource.delete(id);

  @override
  Future<Map<String, double>> getCategoryTotals({
    required DateTime start,
    required DateTime end,
    required TransactionType type,
  }) =>
      _datasource.getCategoryTotals(start: start, end: end, type: type);

  @override
  Future<List<Map<String, dynamic>>> getDailyTotals({
    required DateTime start,
    required DateTime end,
    required TransactionType type,
  }) =>
      _datasource.getDailyTotals(start: start, end: end, type: type);
}
