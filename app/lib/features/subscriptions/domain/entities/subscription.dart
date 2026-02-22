import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';

enum BillingCycle {
  weekly,
  monthly,
  quarterly,
  yearly;

  String get displayName {
    switch (this) {
      case BillingCycle.weekly:
        return 'Weekly';
      case BillingCycle.monthly:
        return 'Monthly';
      case BillingCycle.quarterly:
        return 'Quarterly';
      case BillingCycle.yearly:
        return 'Yearly';
    }
  }

  String get shortLabel {
    switch (this) {
      case BillingCycle.weekly:
        return 'week';
      case BillingCycle.monthly:
        return 'mo';
      case BillingCycle.quarterly:
        return 'qtr';
      case BillingCycle.yearly:
        return 'yr';
    }
  }

  double get monthlyMultiplier {
    switch (this) {
      case BillingCycle.weekly:
        return 4.33;
      case BillingCycle.monthly:
        return 1.0;
      case BillingCycle.quarterly:
        return 1.0 / 3.0;
      case BillingCycle.yearly:
        return 1.0 / 12.0;
    }
  }
}

class Subscription {
  final String id;
  final String name;
  final double amount;
  final TransactionCategory category;
  final BillingCycle billingCycle;
  final String? accountId;
  final DateTime startDate;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.billingCycle,
    this.accountId,
    required this.startDate,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get monthlyAmount => amount * billingCycle.monthlyMultiplier;

  Subscription copyWith({
    String? id,
    String? name,
    double? amount,
    TransactionCategory? category,
    BillingCycle? billingCycle,
    String? accountId,
    DateTime? startDate,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      billingCycle: billingCycle ?? this.billingCycle,
      accountId: accountId ?? this.accountId,
      startDate: startDate ?? this.startDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'category': category.name,
      'billing_cycle': billingCycle.name,
      'account_id': accountId,
      'start_date': startDate.toIso8601String().split('T').first,
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: TransactionCategory.values.byName(map['category'] as String),
      billingCycle: BillingCycle.values.byName(map['billing_cycle'] as String),
      accountId: map['account_id'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      isActive: (map['is_active'] as int?) == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
