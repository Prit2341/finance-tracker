import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/shared/database/app_database.dart';

/// A training sample collected from user interactions.
class TrainingSample {
  final int? id;
  final String merchant;
  final TransactionCategory correctCategory;
  final double weight;
  final DateTime timestamp;

  const TrainingSample({
    this.id,
    required this.merchant,
    required this.correctCategory,
    required this.weight,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'merchant': merchant,
        'correct_category': correctCategory.name,
        'weight': weight,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TrainingSample.fromMap(Map<String, dynamic> map) => TrainingSample(
        id: map['id'] as int?,
        merchant: map['merchant'] as String,
        correctCategory:
            TransactionCategory.values.byName(map['correct_category'] as String),
        weight: (map['weight'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}

/// Collects user feedback for on-device model retraining.
///
/// Every saved transaction produces a training sample:
/// - User corrected the ML prediction → weight 1.0 (strong signal)
/// - User accepted the auto-assigned category → weight 0.5 (weak signal)
/// - No ML prediction was involved → weight 0.3 (manual label)
///
/// Triggers retraining after [retrainThreshold] samples accumulate.
class TrainingBuffer {
  static const int retrainThreshold = 50;

  /// Add a training sample from a saved transaction.
  Future<void> record(Transaction transaction) async {
    final db = await AppDatabase.database;

    final double weight;
    if (transaction.wasCorrected) {
      weight = 1.0; // User corrected ML → strong signal
    } else if (transaction.predictedCategory != null) {
      weight = 0.5; // Accepted auto-assign → weak signal
    } else {
      weight = 0.3; // Manual entry, no ML involvement
    }

    final sample = TrainingSample(
      merchant: transaction.merchant,
      correctCategory: transaction.category,
      weight: weight,
      timestamp: DateTime.now(),
    );

    await db.insert('training_buffer', sample.toMap());
  }

  /// Number of unprocessed samples in the buffer.
  Future<int> get pendingCount async {
    final db = await AppDatabase.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM training_buffer');
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Whether enough samples have accumulated to trigger retraining.
  Future<bool> get shouldRetrain async {
    final count = await pendingCount;
    return count >= retrainThreshold;
  }

  /// Retrieve all pending training samples.
  Future<List<TrainingSample>> getAll() async {
    final db = await AppDatabase.database;
    final rows =
        await db.query('training_buffer', orderBy: 'timestamp ASC');
    return rows.map(TrainingSample.fromMap).toList();
  }

  /// Retrieve samples for a specific category.
  Future<List<TrainingSample>> getByCategory(
      TransactionCategory category) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'training_buffer',
      where: 'correct_category = ?',
      whereArgs: [category.name],
    );
    return rows.map(TrainingSample.fromMap).toList();
  }

  /// Get category distribution of buffered samples.
  Future<Map<TransactionCategory, int>> getCategoryDistribution() async {
    final db = await AppDatabase.database;
    final rows = await db.rawQuery('''
      SELECT correct_category, COUNT(*) as cnt
      FROM training_buffer
      GROUP BY correct_category
    ''');

    final dist = <TransactionCategory, int>{};
    for (final row in rows) {
      final cat = TransactionCategory.values
          .where((c) => c.name == row['correct_category'])
          .firstOrNull;
      if (cat != null) {
        dist[cat] = (row['cnt'] as int?) ?? 0;
      }
    }
    return dist;
  }

  /// Clear all processed samples after successful retraining.
  Future<void> clear() async {
    final db = await AppDatabase.database;
    await db.delete('training_buffer');
  }

  /// Clear samples up to a specific ID (for partial clearing).
  Future<void> clearUpTo(int maxId) async {
    final db = await AppDatabase.database;
    await db.delete('training_buffer', where: 'id <= ?', whereArgs: [maxId]);
  }
}
