import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';

class Budget {
  final String id;
  final TransactionCategory category;
  final double limit;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.category,
    required this.limit,
    required this.createdAt,
    required this.updatedAt,
  });

  Budget copyWith({
    String? id,
    TransactionCategory? category,
    double? limit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category.name,
      'budget_limit': limit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      category: TransactionCategory.values.byName(map['category'] as String),
      limit: (map['budget_limit'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
