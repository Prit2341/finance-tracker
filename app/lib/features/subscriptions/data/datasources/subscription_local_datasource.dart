import 'package:sqflite/sqflite.dart';
import 'package:finance_tracker/shared/database/app_database.dart';
import 'package:finance_tracker/features/subscriptions/domain/entities/subscription.dart';

class SubscriptionLocalDatasource {
  Future<Database> get _db => AppDatabase.database;

  Future<List<Subscription>> getAll() async {
    final db = await _db;
    final maps = await db.query('subscriptions', orderBy: 'created_at DESC');
    return maps.map((map) => Subscription.fromMap(map)).toList();
  }

  Future<List<Subscription>> getActive() async {
    final db = await _db;
    final maps = await db.query(
      'subscriptions',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Subscription.fromMap(map)).toList();
  }

  Future<void> insert(Subscription subscription) async {
    final db = await _db;
    await db.insert('subscriptions', subscription.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Subscription subscription) async {
    final db = await _db;
    await db.update(
      'subscriptions',
      subscription.toMap(),
      where: 'id = ?',
      whereArgs: [subscription.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('subscriptions', where: 'id = ?', whereArgs: [id]);
  }
}
