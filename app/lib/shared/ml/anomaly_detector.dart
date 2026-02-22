import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';

/// Result of anomaly detection on a single transaction.
class AnomalyResult {
  final double reconstructionError;
  final double threshold;
  final bool isAnomaly;

  /// How many standard deviations above normal (z-score of error).
  final double zScore;

  const AnomalyResult({
    required this.reconstructionError,
    required this.threshold,
    required this.isAnomaly,
    required this.zScore,
  });

  /// Anomaly severity: none, low, medium, high.
  String get severity {
    if (!isAnomaly) return 'none';
    if (zScore < 3) return 'low';
    if (zScore < 5) return 'medium';
    return 'high';
  }
}

/// Autoencoder-based anomaly detection for transactions.
///
/// The autoencoder was trained on normal transactions only.
/// Anomalies have high reconstruction error (input ≠ output).
///
/// Feature vector (must match Python preprocessing exactly):
/// [log_amount, cat_groceries..cat_other, dow_sin, dow_cos,
///  dom_sin, dom_cos, hour_sin, hour_cos, is_expense]
class AnomalyDetector {
  final Interpreter _interpreter;
  final List<double> _scalerMean;
  final List<double> _scalerStd;
  final double _threshold;
  final double _normalErrorMean;
  final double _normalErrorStd;
  final int _inputDim;

  AnomalyDetector._({
    required Interpreter interpreter,
    required List<double> scalerMean,
    required List<double> scalerStd,
    required double threshold,
    required double normalErrorMean,
    required double normalErrorStd,
    required int inputDim,
  })  : _interpreter = interpreter,
        _scalerMean = scalerMean,
        _scalerStd = scalerStd,
        _threshold = threshold,
        _normalErrorMean = normalErrorMean,
        _normalErrorStd = normalErrorStd,
        _inputDim = inputDim;

  /// Load anomaly detector from assets. Returns null if model files are missing.
  static Future<AnomalyDetector?> load() async {
    try {
      final modelData = await rootBundle.load('assets/models/anomaly_detector.tflite');
      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/anomaly_detector.tflite');
      await modelFile.writeAsBytes(modelData.buffer.asUint8List());
      final interpreter = Interpreter.fromFile(modelFile);

      final configJson =
          await rootBundle.loadString('assets/models/anomaly_config.json');
      final config = json.decode(configJson) as Map<String, dynamic>;

      final scaler = config['scaler'] as Map<String, dynamic>;
      final scalerMean =
          (scaler['mean'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
      final scalerStd =
          (scaler['std'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();

      return AnomalyDetector._(
        interpreter: interpreter,
        scalerMean: scalerMean,
        scalerStd: scalerStd,
        threshold: (config['threshold'] as num).toDouble(),
        normalErrorMean: (config['normal_error_mean'] as num).toDouble(),
        normalErrorStd: (config['normal_error_std'] as num).toDouble(),
        inputDim: config['input_dim'] as int,
      );
    } catch (e) {
      // Model files not available yet
      return null;
    }
  }

  /// Build the feature vector for a transaction (matching Python exactly).
  List<double> _buildFeatures(Transaction transaction) {
    final features = <double>[];

    // log_amount
    features.add(log(1 + transaction.amount));

    // Category one-hot encoding (12 categories)
    final categories = [
      'groceries', 'dining', 'transport', 'utilities', 'entertainment',
      'healthcare', 'shopping', 'rent', 'salary', 'freelance',
      'transfer', 'other',
    ];
    for (final cat in categories) {
      features.add(transaction.category.name == cat ? 1.0 : 0.0);
    }

    // Day of week (cyclical)
    final dow = transaction.date.weekday - 1; // 0=Mon, 6=Sun
    features.add(sin(2 * pi * dow / 7));
    features.add(cos(2 * pi * dow / 7));

    // Day of month (cyclical)
    final dom = transaction.date.day;
    features.add(sin(2 * pi * dom / 31));
    features.add(cos(2 * pi * dom / 31));

    // Hour (cyclical) — we don't store hour, default to 0
    features.add(sin(2 * pi * 0 / 24)); // 0.0
    features.add(cos(2 * pi * 0 / 24)); // 1.0

    // Transaction type
    features.add(transaction.type == TransactionType.expense ? 1.0 : 0.0);

    return features;
  }

  /// Scale features using the saved StandardScaler parameters.
  List<double> _scale(List<double> features) {
    return List.generate(features.length, (i) {
      final std = _scalerStd[i];
      if (std == 0) return 0.0;
      return (features[i] - _scalerMean[i]) / std;
    });
  }

  /// Detect if a transaction is anomalous.
  AnomalyResult detect(Transaction transaction) {
    final rawFeatures = _buildFeatures(transaction);
    final scaled = _scale(rawFeatures);

    // Run autoencoder: input → reconstructed output
    final input = [scaled];
    final output = List.filled(_inputDim, 0.0).reshape([1, _inputDim]);

    _interpreter.run(input, output);

    // Compute MSE reconstruction error
    final reconstructed = (output[0] as List<double>);
    double mse = 0;
    for (int i = 0; i < _inputDim; i++) {
      final diff = scaled[i] - reconstructed[i];
      mse += diff * diff;
    }
    mse /= _inputDim;

    // Z-score relative to normal transaction errors
    final zScore = _normalErrorStd > 0
        ? (mse - _normalErrorMean) / _normalErrorStd
        : 0.0;

    return AnomalyResult(
      reconstructionError: mse,
      threshold: _threshold,
      isAnomaly: mse > _threshold,
      zScore: zScore,
    );
  }

  /// Batch-detect anomalies for a list of transactions.
  List<AnomalyResult> detectBatch(List<Transaction> transactions) {
    return transactions.map(detect).toList();
  }

  void dispose() {
    _interpreter.close();
  }
}
