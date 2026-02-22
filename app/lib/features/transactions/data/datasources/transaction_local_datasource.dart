import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/shared/database/app_database.dart';

class TransactionLocalDatasource {
  Future<Database> get _db => AppDatabase.database;

  Future<List<Transaction>> getAll() async {
    final db = await _db;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map((map) => Transaction.fromMap(map)).toList();
  }

  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        start.toIso8601String().split('T').first,
        end.toIso8601String().split('T').first,
      ],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Transaction.fromMap(map)).toList();
  }

  Future<List<Transaction>> getByCategory(TransactionCategory category) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [category.name],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Transaction.fromMap(map)).toList();
  }

  Future<void> insert(Transaction transaction) async {
    final db = await _db;
    await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Transaction transaction) async {
    final db = await _db;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getCategoryTotals({
    required DateTime start,
    required DateTime end,
    required TransactionType type,
  }) async {
    final db = await _db;
    final results = await db.rawQuery(
      '''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ? AND type = ?
      GROUP BY category
      ''',
      [
        start.toIso8601String().split('T').first,
        end.toIso8601String().split('T').first,
        type.name,
      ],
    );

    return {
      for (final row in results)
        row['category'] as String: (row['total'] as num).toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>> getDailyTotals({
    required DateTime start,
    required DateTime end,
    required TransactionType type,
  }) async {
    final db = await _db;
    return db.rawQuery(
      '''
      SELECT date, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ? AND type = ?
      GROUP BY date
      ORDER BY date ASC
      ''',
      [
        start.toIso8601String().split('T').first,
        end.toIso8601String().split('T').first,
        type.name,
      ],
    );
  }
}
