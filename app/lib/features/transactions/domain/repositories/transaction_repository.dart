import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';

abstract class TransactionRepository {
  Future<List<Transaction>> getAll();
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);
  Future<List<Transaction>> getByCategory(TransactionCategory category);
  Future<void> add(Transaction transaction);
  Future<void> update(Transaction transaction);
  Future<void> delete(String id);
  Future<Map<String, double>> getCategoryTotals({
    required DateTime start,
    required DateTime end,
    required TransactionType type,
  });
  Future<List<Map<String, dynamic>>> getDailyTotals({
    required DateTime start,
    required DateTime end,
    required TransactionType type,
  });
}
