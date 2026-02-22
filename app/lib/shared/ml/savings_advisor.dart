import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';

/// Risk classification for a user's spending profile.
enum SpendingRisk { healthy, moderate, atRisk }

/// A single savings recommendation.
class SavingsRecommendation {
  final String id;
  final String title;
  final String description;
  final String? category;
  final String priority; // critical, high, medium, low
  final double? potentialSavings; // fraction that could be saved

  const SavingsRecommendation({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    required this.priority,
    this.potentialSavings,
  });
}

/// Result of savings analysis.
class SavingsAnalysis {
  final SpendingRisk risk;
  final String riskTitle;
  final String riskDescription;
  final double savingsRate;
  final double expenseRatio;
  final List<SavingsRecommendation> recommendations;
  final Map<String, double> categoryRatios;

  const SavingsAnalysis({
    required this.risk,
    required this.riskTitle,
    required this.riskDescription,
    required this.savingsRate,
    required this.expenseRatio,
    required this.recommendations,
    required this.categoryRatios,
  });
}

/// Rule template loaded from JSON.
class _RuleTemplate {
  final String id;
  final String title;
  final String description;
  final String? category;
  final double threshold;
  final String priority;
  final double? potentialSavings;

  _RuleTemplate({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    required this.threshold,
    required this.priority,
    this.potentialSavings,
  });

  factory _RuleTemplate.fromJson(Map<String, dynamic> json) => _RuleTemplate(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String?,
        threshold: (json['threshold'] as num).toDouble(),
        priority: json['priority'] as String,
        potentialSavings: (json['potential_savings'] as num?)?.toDouble(),
      );
}

/// Personalized savings recommendations using TFLite risk classifier + rule engine.
///
/// Two-part system:
/// 1. TFLite model classifies spending profile into risk levels
/// 2. Rule engine generates specific actionable tips based on category spending
class SavingsAdvisor {
  final Interpreter? _interpreter;
  final List<double> _scalerMean;
  final List<double> _scalerStd;
  final List<_RuleTemplate> _rules;
  final Map<String, Map<String, String>> _riskLevels;

  SavingsAdvisor._({
    Interpreter? interpreter,
    required List<double> scalerMean,
    required List<double> scalerStd,
    required List<_RuleTemplate> rules,
    required Map<String, Map<String, String>> riskLevels,
  })  : _interpreter = interpreter,
        _scalerMean = scalerMean,
        _scalerStd = scalerStd,
        _rules = rules,
        _riskLevels = riskLevels;

  /// Load savings advisor from assets. Returns null if files are missing.
  static Future<SavingsAdvisor?> load() async {
    try {
      // Load recommendation templates (always needed)
      final templatesJson = await rootBundle
          .loadString('assets/models/recommendation_templates.json');
      final templates =
          json.decode(templatesJson) as Map<String, dynamic>;

      final rulesJson = templates['rules'] as List<dynamic>;
      final rules =
          rulesJson.map((r) => _RuleTemplate.fromJson(r as Map<String, dynamic>)).toList();

      final riskLevelsRaw =
          templates['risk_levels'] as Map<String, dynamic>;
      final riskLevels = riskLevelsRaw.map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, v.toString())),
        ),
      );

      // Try to load TFLite model (optional — rule engine works without it)
      Interpreter? interpreter;
      List<double> scalerMean = [];
      List<double> scalerStd = [];

      try {
        final modelData = await rootBundle.load('assets/models/savings_advisor.tflite');
        final tempDir = await getTemporaryDirectory();
        final modelFile = File('${tempDir.path}/savings_advisor.tflite');
        await modelFile.writeAsBytes(modelData.buffer.asUint8List());
        interpreter = Interpreter.fromFile(modelFile);

        final configJson = await rootBundle
            .loadString('assets/models/savings_config.json');
        final config =
            json.decode(configJson) as Map<String, dynamic>;

        final scaler = config['scaler'] as Map<String, dynamic>;
        scalerMean = (scaler['mean'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();
        scalerStd = (scaler['std'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();
      } catch (_) {
        // Model not available — rule engine still works
      }

      return SavingsAdvisor._(
        interpreter: interpreter,
        scalerMean: scalerMean,
        scalerStd: scalerStd,
        rules: rules,
        riskLevels: riskLevels,
      );
    } catch (e) {
      return null;
    }
  }

  /// Analyze spending and generate recommendations.
  SavingsAnalysis analyze(List<Transaction> transactions) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    // Current month transactions
    final currentMonth = transactions
        .where((t) => !t.date.isBefore(monthStart))
        .toList();

    // Last month transactions
    final lastMonth = transactions
        .where((t) =>
            !t.date.isBefore(lastMonthStart) && t.date.isBefore(monthStart))
        .toList();

    // Calculate totals
    final income = currentMonth
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final expenses = currentMonth
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final lastMonthExpenses = lastMonth
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);

    final effectiveIncome = income > 0 ? income : expenses * 1.2;
    final expenseRatio = expenses / effectiveIncome;
    final savingsRate = 1.0 - expenseRatio;

    // Category spending ratios
    final categoryTotals = <String, double>{};
    for (final t
        in currentMonth.where((t) => t.type == TransactionType.expense)) {
      categoryTotals[t.category.name] =
          (categoryTotals[t.category.name] ?? 0) + t.amount;
    }
    final categoryRatios = <String, double>{};
    for (final entry in categoryTotals.entries) {
      categoryRatios[entry.key] =
          expenses > 0 ? entry.value / expenses : 0;
    }

    // Month-over-month change
    final momIncrease = lastMonthExpenses > 0
        ? (expenses - lastMonthExpenses) / lastMonthExpenses
        : 0.0;

    // Classify risk
    SpendingRisk risk;
    if (_interpreter != null && _scalerMean.isNotEmpty) {
      risk = _classifyWithModel(
          expenseRatio, savingsRate, categoryRatios);
    } else {
      risk = _classifyWithRules(savingsRate, expenseRatio);
    }

    final riskKey = _riskKeyFromEnum(risk);
    final riskInfo = _riskLevels[riskKey] ?? {};

    // Generate recommendations
    final recommendations = _generateRecommendations(
      categoryRatios: categoryRatios,
      savingsRate: savingsRate,
      momIncrease: momIncrease,
      expenses: expenses,
    );

    return SavingsAnalysis(
      risk: risk,
      riskTitle: riskInfo['title'] ?? 'Unknown',
      riskDescription: riskInfo['description'] ?? '',
      savingsRate: savingsRate,
      expenseRatio: expenseRatio,
      recommendations: recommendations,
      categoryRatios: categoryRatios,
    );
  }

  SpendingRisk _classifyWithModel(
    double expenseRatio,
    double savingsRate,
    Map<String, double> categoryRatios,
  ) {
    // Build feature vector matching Python preprocessing
    final discretionary = (categoryRatios['dining'] ?? 0) +
        (categoryRatios['entertainment'] ?? 0) +
        (categoryRatios['shopping'] ?? 0);
    final essential = (categoryRatios['rent'] ?? 0) +
        (categoryRatios['utilities'] ?? 0) +
        (categoryRatios['groceries'] ?? 0) +
        (categoryRatios['transport'] ?? 0);

    final features = [
      expenseRatio,
      savingsRate,
      discretionary,
      essential,
      0.3, // credit_util default
    ];

    // Scale
    final scaled = List.generate(features.length, (i) {
      if (i >= _scalerMean.length || _scalerStd[i] == 0) return 0.0;
      return (features[i] - _scalerMean[i]) / _scalerStd[i];
    });

    final input = [scaled];
    final output = List.filled(3, 0.0).reshape([1, 3]);

    _interpreter!.run(input, output);

    final scores = output[0] as List<double>;
    final maxIdx = scores.indexOf(
        scores.reduce((a, b) => a > b ? a : b));

    return SpendingRisk.values[maxIdx.clamp(0, 2)];
  }

  SpendingRisk _classifyWithRules(double savingsRate, double expenseRatio) {
    if (savingsRate > 0.20) return SpendingRisk.healthy;
    if (savingsRate > 0.05) return SpendingRisk.moderate;
    return SpendingRisk.atRisk;
  }

  List<SavingsRecommendation> _generateRecommendations({
    required Map<String, double> categoryRatios,
    required double savingsRate,
    required double momIncrease,
    required double expenses,
  }) {
    final tips = <SavingsRecommendation>[];

    for (final rule in _rules) {
      bool triggered = false;
      String description = rule.description;

      if (rule.category != null) {
        // Category-based rule
        final ratio = categoryRatios[rule.category] ?? 0;
        if (ratio > rule.threshold) {
          triggered = true;
          description = description.replaceAll(
              '{ratio}', (ratio * 100).toStringAsFixed(0));
        }
      } else if (rule.id == 'no_savings') {
        if (savingsRate < rule.threshold) {
          triggered = true;
        }
      } else if (rule.id == 'spending_increase') {
        if (momIncrease > rule.threshold) {
          triggered = true;
          description = description.replaceAll(
              '{increase}', (momIncrease * 100).toStringAsFixed(0));
        }
      }

      if (triggered) {
        tips.add(SavingsRecommendation(
          id: rule.id,
          title: rule.title,
          description: description,
          category: rule.category,
          priority: rule.priority,
          potentialSavings: rule.potentialSavings,
        ));
      }
    }

    // Sort by priority
    const priorityOrder = {
      'critical': 0,
      'high': 1,
      'medium': 2,
      'low': 3,
    };
    tips.sort((a, b) =>
        (priorityOrder[a.priority] ?? 9)
            .compareTo(priorityOrder[b.priority] ?? 9));

    return tips;
  }

  String _riskKeyFromEnum(SpendingRisk risk) {
    switch (risk) {
      case SpendingRisk.healthy:
        return 'healthy';
      case SpendingRisk.moderate:
        return 'moderate';
      case SpendingRisk.atRisk:
        return 'at_risk';
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
