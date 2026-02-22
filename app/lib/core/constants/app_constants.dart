import 'package:flutter/material.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';

class AppConstants {
  static const String appName = 'Finance Tracker';

  static const Map<TransactionCategory, IconData> categoryIcons = {
    TransactionCategory.groceries: Icons.shopping_cart,
    TransactionCategory.dining: Icons.restaurant,
    TransactionCategory.transport: Icons.directions_car,
    TransactionCategory.utilities: Icons.bolt,
    TransactionCategory.entertainment: Icons.movie,
    TransactionCategory.healthcare: Icons.local_hospital,
    TransactionCategory.shopping: Icons.shopping_bag,
    TransactionCategory.rent: Icons.home,
    TransactionCategory.salary: Icons.work,
    TransactionCategory.freelance: Icons.laptop,
    TransactionCategory.transfer: Icons.swap_horiz,
    TransactionCategory.other: Icons.more_horiz,
  };

  static const Map<TransactionCategory, Color> categoryColors = {
    TransactionCategory.groceries: Color(0xFF4CAF50),
    TransactionCategory.dining: Color(0xFFFF9800),
    TransactionCategory.transport: Color(0xFF2196F3),
    TransactionCategory.utilities: Color(0xFFFFC107),
    TransactionCategory.entertainment: Color(0xFF9C27B0),
    TransactionCategory.healthcare: Color(0xFFF44336),
    TransactionCategory.shopping: Color(0xFFE91E63),
    TransactionCategory.rent: Color(0xFF795548),
    TransactionCategory.salary: Color(0xFF009688),
    TransactionCategory.freelance: Color(0xFF00BCD4),
    TransactionCategory.transfer: Color(0xFF607D8B),
    TransactionCategory.other: Color(0xFF9E9E9E),
  };
}
