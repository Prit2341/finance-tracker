import 'package:sqflite/sqflite.dart';
import 'package:finance_tracker/shared/database/app_database.dart';
import 'package:finance_tracker/features/budgets/domain/entities/budget.dart';

class BudgetLocalDatasource {
  Future<Database> get _db => AppDatabase.database;

  Future<List<Budget>> getAll() async {
    final db = await _db;
    final maps = await db.query('budgets', orderBy: 'category ASC');
    return maps.map((map) => Budget.fromMap(map)).toList();
  }

  Future<void> insert(Budget budget) async {
    final db = await _db;
    await db.insert('budgets', budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Budget budget) async {
    final db = await _db;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }
}
