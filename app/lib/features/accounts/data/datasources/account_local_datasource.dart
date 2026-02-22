import 'package:sqflite/sqflite.dart';
import 'package:finance_tracker/shared/database/app_database.dart';
import 'package:finance_tracker/features/accounts/domain/entities/bank_account.dart';

class AccountLocalDatasource {
  Future<Database> get _db => AppDatabase.database;

  Future<List<BankAccount>> getAll() async {
    final db = await _db;
    final maps = await db.query('bank_accounts', orderBy: 'created_at DESC');
    return maps.map((map) => BankAccount.fromMap(map)).toList();
  }

  Future<BankAccount?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'bank_accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return BankAccount.fromMap(maps.first);
  }

  Future<void> insert(BankAccount account) async {
    final db = await _db;
    await db.insert('bank_accounts', account.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(BankAccount account) async {
    final db = await _db;
    await db.update(
      'bank_accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('bank_accounts', where: 'id = ?', whereArgs: [id]);
  }
}
