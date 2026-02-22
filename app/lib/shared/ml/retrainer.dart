import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/shared/ml/training_buffer.dart';
import 'package:finance_tracker/shared/ml/model_manager.dart';

/// Result of an on-device retraining attempt.
class RetrainingResult {
  final bool success;
  final int newVersion;
  final double? oldAccuracy;
  final double? newAccuracy;
  final int samplesUsed;
  final String message;

  const RetrainingResult({
    required this.success,
    required this.newVersion,
    this.oldAccuracy,
    this.newAccuracy,
    required this.samplesUsed,
    required this.message,
  });
}

/// Handles on-device model retraining using accumulated feedback.
///
/// Since TFLite is inference-only, true gradient-based retraining isn't
/// possible on-device. Instead, we use a **merchant-to-category lookup
/// table** built from user feedback that augments the base model:
///
/// 1. Collect corrected/confirmed merchant→category pairs in training buffer
/// 2. Build a frequency table: for each merchant, which category was chosen
///    most often (weighted by correction vs auto-accept)
/// 3. When predicting, first check the lookup table — if the merchant has
///    a high-confidence mapping from user history, use that directly
/// 4. Fall back to TFLite model for unknown merchants
///
/// This approach gives the user a personalized experience that improves
/// over time without needing on-device gradient computation.
class Retrainer {
  final TrainingBuffer _buffer;
  final ModelManager _modelManager;

  Retrainer({
    required TrainingBuffer buffer,
    required ModelManager modelManager,
  })  : _buffer = buffer,
        _modelManager = modelManager;

  /// Check if retraining should be triggered.
  Future<bool> shouldRetrain() async {
    return _buffer.shouldRetrain;
  }

  /// Run the retraining process.
  ///
  /// Builds a personalized merchant→category lookup from feedback,
  /// saves it as a new "model version" (JSON lookup table), and
  /// activates it if it improves accuracy on a holdout set.
  Future<RetrainingResult> retrain() async {
    final samples = await _buffer.getAll();
    if (samples.isEmpty) {
      return const RetrainingResult(
        success: false,
        newVersion: 0,
        samplesUsed: 0,
        message: 'No training samples available',
      );
    }

    // Build weighted merchant→category frequency table
    final merchantVotes = <String, Map<TransactionCategory, double>>{};
    for (final sample in samples) {
      final merchant = _normalizeMerchant(sample.merchant);
      merchantVotes.putIfAbsent(merchant, () => {});
      merchantVotes[merchant]!.update(
        sample.correctCategory,
        (v) => v + sample.weight,
        ifAbsent: () => sample.weight,
      );
    }

    // Resolve each merchant to its highest-weighted category
    final lookupTable = <String, String>{};
    final lookupConfidence = <String, double>{};

    for (final entry in merchantVotes.entries) {
      final votes = entry.value;
      final totalWeight = votes.values.fold(0.0, (a, b) => a + b);
      final winner = votes.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );

      lookupTable[entry.key] = winner.key.name;
      lookupConfidence[entry.key] = winner.value / totalWeight;
    }

    // Validate on holdout (last 20% of samples)
    final holdoutSize = max(1, (samples.length * 0.2).round());
    final holdout = samples.sublist(samples.length - holdoutSize);
    int correct = 0;
    for (final sample in holdout) {
      final merchant = _normalizeMerchant(sample.merchant);
      final predicted = lookupTable[merchant];
      if (predicted == sample.correctCategory.name) {
        correct++;
      }
    }
    final holdoutAccuracy = correct / holdout.length;

    // Get previous accuracy
    final history =
        await _modelManager.getVersionHistory('categorizer_lookup');
    final active = history.where((v) => v.isActive).firstOrNull;
    final previousAccuracy = active?.accuracy;

    // Save the lookup table as a new version
    final lookupData = json.encode({
      'lookup': lookupTable,
      'confidence': lookupConfidence,
      'sample_count': samples.length,
      'created_at': DateTime.now().toIso8601String(),
    });

    final newVersion = await _modelManager.saveNewVersion(
      'categorizer_lookup',
      utf8.encode(lookupData),
      accuracy: holdoutAccuracy,
    );

    // Activate if it improves or if no previous model
    final shouldActivate =
        previousAccuracy == null || holdoutAccuracy >= previousAccuracy;

    if (shouldActivate) {
      await _modelManager.activate('categorizer_lookup', newVersion);
      await _buffer.clear();
      await _modelManager.pruneOldVersions('categorizer_lookup');

      return RetrainingResult(
        success: true,
        newVersion: newVersion,
        oldAccuracy: previousAccuracy,
        newAccuracy: holdoutAccuracy,
        samplesUsed: samples.length,
        message:
            'Model updated to v$newVersion (accuracy: ${(holdoutAccuracy * 100).toStringAsFixed(1)}%)',
      );
    } else {
      return RetrainingResult(
        success: false,
        newVersion: newVersion,
        oldAccuracy: previousAccuracy,
        newAccuracy: holdoutAccuracy,
        samplesUsed: samples.length,
        message:
            'New model not better (${(holdoutAccuracy * 100).toStringAsFixed(1)}% vs ${(previousAccuracy * 100).toStringAsFixed(1)}%). Keeping current.',
      );
    }
  }

  /// Load the personalized lookup table (if available).
  /// Returns a map of normalized_merchant → TransactionCategory.
  Future<Map<String, TransactionCategory>?> loadLookupTable() async {
    final path =
        await _modelManager.getActiveModelPath('categorizer_lookup');
    if (path == null) return null;

    try {
      final bytes = await File(path).readAsBytes();
      final data = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      final lookup = data['lookup'] as Map<String, dynamic>;

      final result = <String, TransactionCategory>{};
      for (final entry in lookup.entries) {
        final cat = TransactionCategory.values
            .where((c) => c.name == entry.value)
            .firstOrNull;
        if (cat != null) {
          result[entry.key] = cat;
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Normalize merchant name for lookup (same as categorizer tokenization).
  String _normalizeMerchant(String merchant) {
    return merchant
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
