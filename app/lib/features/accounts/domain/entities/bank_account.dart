class BankAccount {
  final String id;
  final String name;
  final String bankName;
  final double totalBalance;
  final double usableAmount;
  final double savingsAmount;
  final double minimumBalance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BankAccount({
    required this.id,
    required this.name,
    required this.bankName,
    required this.totalBalance,
    required this.usableAmount,
    required this.savingsAmount,
    required this.minimumBalance,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isBelowMinimum => usableAmount <= minimumBalance;

  bool get isNearMinimum =>
      !isBelowMinimum && usableAmount <= minimumBalance * 1.1;

  BankAccount copyWith({
    String? id,
    String? name,
    String? bankName,
    double? totalBalance,
    double? usableAmount,
    double? savingsAmount,
    double? minimumBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BankAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      bankName: bankName ?? this.bankName,
      totalBalance: totalBalance ?? this.totalBalance,
      usableAmount: usableAmount ?? this.usableAmount,
      savingsAmount: savingsAmount ?? this.savingsAmount,
      minimumBalance: minimumBalance ?? this.minimumBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bank_name': bankName,
      'total_balance': totalBalance,
      'usable_amount': usableAmount,
      'savings_amount': savingsAmount,
      'minimum_balance': minimumBalance,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: map['id'] as String,
      name: map['name'] as String,
      bankName: map['bank_name'] as String,
      totalBalance: (map['total_balance'] as num).toDouble(),
      usableAmount: (map['usable_amount'] as num).toDouble(),
      savingsAmount: (map['savings_amount'] as num).toDouble(),
      minimumBalance: (map['minimum_balance'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
