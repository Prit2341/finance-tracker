import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';

class CsvExporter {
  /// Export transactions to a CSV file. Returns the file path.
  static Future<String> export(List<Transaction> transactions) async {
    final rows = <List<dynamic>>[
      // Header
      [
        'id',
        'date',
        'type',
        'amount',
        'merchant',
        'category',
        'description',
        'is_anomaly',
        'anomaly_score',
        'predicted_category',
        'confidence',
        'was_corrected',
      ],
      // Data rows
      for (final t in transactions)
        [
          t.id,
          t.date.toIso8601String().split('T').first,
          t.type.name,
          t.amount,
          t.merchant,
          t.category.name,
          t.description ?? '',
          t.isAnomaly ? 1 : 0,
          t.anomalyScore ?? '',
          t.predictedCategory?.name ?? '',
          t.confidence ?? '',
          t.wasCorrected ? 1 : 0,
        ],
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/finance_tracker_export_$timestamp.csv');
    await file.writeAsString(csv);
    return file.path;
  }
}
