import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';

/// Result of a 7-day spending forecast.
class ForecastResult {
  /// Predicted daily spending amounts for the next 7 days.
  final List<double> dailyPredictions;

  /// Total predicted spending for the next 7 days.
  double get totalPredicted =>
      dailyPredictions.fold(0.0, (a, b) => a + b);

  /// Average predicted daily spending.
  double get averageDaily =>
      dailyPredictions.isEmpty ? 0 : totalPredicted / dailyPredictions.length;

  const ForecastResult({required this.dailyPredictions});
}

/// LSTM-based 7-day spending forecaster.
///
/// Input: last 30 days of daily spending totals (scaled to [0,1])
/// Output: next 7 days of predicted daily spending
///
/// Requires at least [lookback] days of transaction history.
class Forecaster {
  final Interpreter _interpreter;
  final int _lookback;
  final int _horizon;
  final double _scalerMin;
  final double _scalerMax;

  Forecaster._({
    required Interpreter interpreter,
    required int lookback,
    required int horizon,
    required double scalerMin,
    required double scalerMax,
  })  : _interpreter = interpreter,
        _lookback = lookback,
        _horizon = horizon,
        _scalerMin = scalerMin,
        _scalerMax = scalerMax;

  int get lookback => _lookback;
  int get horizon => _horizon;

  /// Load forecaster from assets. Returns null if model files are missing.
  static Future<Forecaster?> load() async {
    try {
      final modelData = await rootBundle.load('assets/models/forecast.tflite');
      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/forecast.tflite');
      await modelFile.writeAsBytes(modelData.buffer.asUint8List());
      final interpreter = Interpreter.fromFile(modelFile);

      final configJson =
          await rootBundle.loadString('assets/models/forecast_config.json');
      final config = json.decode(configJson) as Map<String, dynamic>;

      return Forecaster._(
        interpreter: interpreter,
        lookback: config['lookback'] as int,
        horizon: config['horizon'] as int,
        scalerMin: ((config['scaler'] as Map<String, dynamic>)['min'] as num).toDouble(),
        scalerMax: ((config['scaler'] as Map<String, dynamic>)['max'] as num).toDouble(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Scale a value to [0, 1] using MinMaxScaler params.
  double _scale(double value) {
    final range = _scalerMax - _scalerMin;
    if (range == 0) return 0;
    return (value - _scalerMin) / range;
  }

  /// Inverse-scale from [0, 1] back to dollar amounts.
  double _inverseScale(double scaled) {
    return scaled * (_scalerMax - _scalerMin) + _scalerMin;
  }

  /// Build daily spending totals from transactions.
  /// Returns a list of (date, total) for the last [lookback] days.
  List<double> _buildDailySeries(List<Transaction> transactions) {
    final now = DateTime.now();
    final dailyTotals = <double>[];

    for (int i = _lookback - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayTotal = transactions
          .where((t) =>
              t.type == TransactionType.expense &&
              !t.date.isBefore(dayStart) &&
              t.date.isBefore(dayEnd))
          .fold(0.0, (sum, t) => sum + t.amount);

      dailyTotals.add(dayTotal);
    }

    return dailyTotals;
  }

  /// Predict the next 7 days of spending.
  ///
  /// Returns null if not enough transaction history (< [lookback] days).
  ForecastResult? predict(List<Transaction> transactions) {
    // Check if we have enough history
    if (transactions.isEmpty) return null;

    final oldestDate = transactions
        .map((t) => t.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final daysCovered = DateTime.now().difference(oldestDate).inDays;
    if (daysCovered < _lookback) return null;

    // Build and scale input
    final dailySeries = _buildDailySeries(transactions);
    final scaledInput = dailySeries.map(_scale).toList();

    // Reshape for LSTM: [1, lookback, 1]
    final input = [
      scaledInput.map((v) => [v]).toList()
    ];
    final output = List.filled(_horizon, 0.0).reshape([1, _horizon]);

    _interpreter.run(input, output);

    // Inverse-scale predictions and clamp to non-negative
    final predictions = (output[0] as List<double>)
        .map((v) => _inverseScale(v).clamp(0.0, double.infinity))
        .toList();

    return ForecastResult(dailyPredictions: predictions);
  }

  void dispose() {
    _interpreter.close();
  }
}
