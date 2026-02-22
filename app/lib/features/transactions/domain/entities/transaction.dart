enum TransactionType { income, expense }

enum TransactionCategory {
  groceries,
  dining,
  transport,
  utilities,
  entertainment,
  healthcare,
  shopping,
  rent,
  salary,
  freelance,
  transfer,
  other;

  String get displayName {
    switch (this) {
      case TransactionCategory.groceries:
        return 'Groceries';
      case TransactionCategory.dining:
        return 'Dining';
      case TransactionCategory.transport:
        return 'Transport';
      case TransactionCategory.utilities:
        return 'Utilities';
      case TransactionCategory.entertainment:
        return 'Entertainment';
      case TransactionCategory.healthcare:
        return 'Healthcare';
      case TransactionCategory.shopping:
        return 'Shopping';
      case TransactionCategory.rent:
        return 'Rent';
      case TransactionCategory.salary:
        return 'Salary';
      case TransactionCategory.freelance:
        return 'Freelance';
      case TransactionCategory.transfer:
        return 'Transfer';
      case TransactionCategory.other:
        return 'Other';
    }
  }
}

class Transaction {
  final String id;
  final double amount;
  final String merchant;
  final String? description;
  final TransactionCategory category;
  final DateTime date;
  final TransactionType type;
  final bool isAnomaly;
  final TransactionCategory? predictedCategory;
  final double? confidence;
  final double? anomalyScore;
  final bool wasCorrected;
  final String? accountId;

  const Transaction({
    required this.id,
    required this.amount,
    required this.merchant,
    this.description,
    required this.category,
    required this.date,
    required this.type,
    this.isAnomaly = false,
    this.predictedCategory,
    this.confidence,
    this.anomalyScore,
    this.wasCorrected = false,
    this.accountId,
  });

  Transaction copyWith({
    String? id,
    double? amount,
    String? merchant,
    String? description,
    TransactionCategory? category,
    DateTime? date,
    TransactionType? type,
    bool? isAnomaly,
    TransactionCategory? predictedCategory,
    double? confidence,
    double? anomalyScore,
    bool? wasCorrected,
    String? accountId,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      type: type ?? this.type,
      isAnomaly: isAnomaly ?? this.isAnomaly,
      predictedCategory: predictedCategory ?? this.predictedCategory,
      confidence: confidence ?? this.confidence,
      anomalyScore: anomalyScore ?? this.anomalyScore,
      wasCorrected: wasCorrected ?? this.wasCorrected,
      accountId: accountId ?? this.accountId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'merchant': merchant,
      'description': description,
      'category': category.name,
      'date': date.toIso8601String().split('T').first,
      'type': type.name,
      'is_anomaly': isAnomaly ? 1 : 0,
      'predicted_category': predictedCategory?.name,
      'confidence': confidence,
      'anomaly_score': anomalyScore,
      'was_corrected': wasCorrected ? 1 : 0,
      'account_id': accountId,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] as String,
      description: map['description'] as String?,
      category: TransactionCategory.values.byName(map['category'] as String),
      date: DateTime.parse(map['date'] as String),
      type: TransactionType.values.byName(map['type'] as String),
      isAnomaly: (map['is_anomaly'] as int?) == 1,
      predictedCategory: map['predicted_category'] != null
          ? TransactionCategory.values.byName(map['predicted_category'] as String)
          : null,
      confidence: (map['confidence'] as num?)?.toDouble(),
      anomalyScore: (map['anomaly_score'] as num?)?.toDouble(),
      wasCorrected: (map['was_corrected'] as int?) == 1,
      accountId: map['account_id'] as String?,
    );
  }
}
