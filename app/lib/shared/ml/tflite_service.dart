import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  Interpreter? _categorizer;
  Interpreter? _anomalyDetector;
  Interpreter? _forecaster;

  bool get isCategorizerReady => _categorizer != null;
  bool get isAnomalyDetectorReady => _anomalyDetector != null;
  bool get isForecasterReady => _forecaster != null;

  Future<void> initialize() async {
    try {
      _categorizer = await Interpreter.fromAsset('models/categorizer.tflite');
    } catch (e) {
      // Model not yet available — ML features disabled until trained
    }

    try {
      _anomalyDetector =
          await Interpreter.fromAsset('models/anomaly_detector.tflite');
    } catch (e) {
      // Model not yet available
    }

    try {
      _forecaster = await Interpreter.fromAsset('models/forecast.tflite');
    } catch (e) {
      // Model not yet available
    }
  }

  Interpreter? get categorizer => _categorizer;
  Interpreter? get anomalyDetector => _anomalyDetector;
  Interpreter? get forecaster => _forecaster;

  void dispose() {
    _categorizer?.close();
    _anomalyDetector?.close();
    _forecaster?.close();
  }

  /// Load a JSON config file from assets.
  static Future<Map<String, dynamic>> loadJsonAsset(String path) async {
    final jsonStr = await rootBundle.loadString('assets/$path');
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  /// Load a JSON list from assets.
  static Future<List<dynamic>> loadJsonListAsset(String path) async {
    final jsonStr = await rootBundle.loadString('assets/$path');
    return json.decode(jsonStr) as List<dynamic>;
  }
}
