import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_tracker/shared/ml/categorizer.dart';
import 'package:finance_tracker/shared/ml/training_buffer.dart';
import 'package:finance_tracker/shared/ml/model_manager.dart';
import 'package:finance_tracker/shared/ml/retrainer.dart';
import 'package:finance_tracker/shared/ml/anomaly_detector.dart';
import 'package:finance_tracker/shared/ml/forecaster.dart';
import 'package:finance_tracker/shared/ml/savings_advisor.dart';

final categorizerProvider = FutureProvider<Categorizer?>((ref) async {
  return Categorizer.load();
});

final trainingBufferProvider = Provider<TrainingBuffer>((ref) {
  return TrainingBuffer();
});

final modelManagerProvider = Provider<ModelManager>((ref) {
  return ModelManager();
});

final retrainerProvider = Provider<Retrainer>((ref) {
  return Retrainer(
    buffer: ref.watch(trainingBufferProvider),
    modelManager: ref.watch(modelManagerProvider),
  );
});

/// Tracks the number of pending training samples for UI display.
final pendingTrainingSamplesProvider = FutureProvider<int>((ref) async {
  final buffer = ref.watch(trainingBufferProvider);
  return buffer.pendingCount;
});

final anomalyDetectorProvider = FutureProvider<AnomalyDetector?>((ref) async {
  return AnomalyDetector.load();
});

final forecasterProvider = FutureProvider<Forecaster?>((ref) async {
  return Forecaster.load();
});

final savingsAdvisorProvider = FutureProvider<SavingsAdvisor?>((ref) async {
  return SavingsAdvisor.load();
});
