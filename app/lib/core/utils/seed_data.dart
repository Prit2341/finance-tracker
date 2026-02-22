import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/shared/database/app_database.dart';

class SeedData {
  /// Import seed transactions on first launch. No-op if already seeded.
  static Future<void> importIfNeeded() async {
    final db = await AppDatabase.database;

    // Check if we already seeded
    final count = await db.rawQuery('SELECT COUNT(*) as c FROM transactions');
    if ((count.first['c'] as int) > 0) return;

    // Load seed data from assets
    final jsonStr =
        await rootBundle.loadString('assets/data/seed_transactions.json');
    final list = json.decode(jsonStr) as List<dynamic>;

    const uuid = Uuid();
    final batch = db.batch();

    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final transaction = Transaction(
        id: uuid.v4(),
        amount: (map['amount'] as num).toDouble(),
        merchant: map['merchant'] as String,
        description: map['description'] as String?,
        category:
            TransactionCategory.values.byName(map['category'] as String),
        date: DateTime.parse(map['date'] as String),
        type: TransactionType.values.byName(map['type'] as String),
      );
      batch.insert('transactions', transaction.toMap());
    }

    await batch.commit(noResult: true);
  }
}
