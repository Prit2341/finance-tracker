import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';

/// Prediction result with confidence scores.
class CategoryPrediction {
  final TransactionCategory category;
  final double confidence;

  const CategoryPrediction({
    required this.category,
    required this.confidence,
  });
}

/// Auto-categorization using TFLite model.
/// Replicates the Python tokenization pipeline exactly:
/// lowercase → split on whitespace → map to word indices → pad to maxLen.
class Categorizer {
  final Interpreter _interpreter;
  final Map<String, int> _wordIndex;
  final List<String> _categories;
  final int _maxLen;
  final double confidenceThreshold;

  Categorizer._({
    required Interpreter interpreter,
    required Map<String, int> wordIndex,
    required List<String> categories,
    required int maxLen,
    this.confidenceThreshold = 0.8,
  })  : _interpreter = interpreter,
        _wordIndex = wordIndex,
        _categories = categories,
        _maxLen = maxLen;

  /// Load categorizer from assets. Returns null if model files are missing.
  static Future<Categorizer?> load() async {
    try {
      debugPrint('Categorizer: step 1 - loading asset bytes...');
      final modelData = await rootBundle.load('assets/models/categorizer.tflite');
      debugPrint('Categorizer: step 2 - got ${modelData.lengthInBytes} bytes, writing to temp file...');
      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/categorizer.tflite');
      await modelFile.writeAsBytes(modelData.buffer.asUint8List());
      debugPrint('Categorizer: step 3 - creating interpreter from ${modelFile.path}...');
      final interpreter = Interpreter.fromFile(modelFile);
      debugPrint('Categorizer: step 4 - interpreter created, loading tokenizer...');

      // Load tokenizer word index
      final tokenizerJson =
          await rootBundle.loadString('assets/models/tokenizer.json');
      final wordIndexRaw =
          json.decode(tokenizerJson) as Map<String, dynamic>;
      final wordIndex = wordIndexRaw
          .map((key, value) => MapEntry(key, value as int));

      // Load category labels
      final categoriesJson =
          await rootBundle.loadString('assets/models/categories.json');
      final categories = (json.decode(categoriesJson) as List<dynamic>)
          .cast<String>();

      // Load config
      final configJson =
          await rootBundle.loadString('assets/models/categorizer_config.json');
      final config = json.decode(configJson) as Map<String, dynamic>;
      final maxLen = config['max_len'] as int? ?? 10;
      final threshold =
          (config['confidence_threshold'] as num?)?.toDouble() ?? 0.8;

      return Categorizer._(
        interpreter: interpreter,
        wordIndex: wordIndex,
        categories: categories,
        maxLen: maxLen,
        confidenceThreshold: threshold,
      );
    } catch (e) {
      debugPrint('Categorizer.load() failed: $e');
      return null;
    }
  }

  /// Tokenize merchant name exactly like Python preprocessing.
  List<int> _tokenize(String text) {
    // Lowercase and clean (match preprocessing.clean_merchant_text)
    final cleaned = text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final words = cleaned.split(' ');
    final indices = words.map((w) => _wordIndex[w] ?? 1).toList(); // 1 = OOV

    // Pad or truncate to maxLen (post-padding with 0)
    while (indices.length < _maxLen) {
      indices.add(0);
    }
    return indices.sublist(0, _maxLen);
  }

  /// Predict category for a merchant name.
  /// Returns top-3 predictions sorted by confidence.
  List<CategoryPrediction> predict(String merchantName) {
    final input = [_tokenize(merchantName).map((e) => e.toDouble()).toList()];
    final output = List.filled(_categories.length, 0.0).reshape([1, _categories.length]);

    _interpreter.run(input, output);

    final scores = (output[0] as List<double>);

    // Build predictions sorted by confidence
    final predictions = <CategoryPrediction>[];
    for (int i = 0; i < _categories.length; i++) {
      final catName = _categories[i];
      final category = TransactionCategory.values
          .where((c) => c.name == catName)
          .firstOrNull;
      if (category != null) {
        predictions.add(CategoryPrediction(
          category: category,
          confidence: scores[i],
        ));
      }
    }

    predictions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return predictions.take(3).toList();
  }

  /// Returns true if the top prediction is above the confidence threshold.
  bool shouldAutoAssign(List<CategoryPrediction> predictions) {
    return predictions.isNotEmpty &&
        predictions.first.confidence >= confidenceThreshold;
  }

  void dispose() {
    _interpreter.close();
  }
}
