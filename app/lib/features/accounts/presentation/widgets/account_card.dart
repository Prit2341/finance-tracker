import 'package:flutter/material.dart';
import 'package:finance_tracker/features/accounts/domain/entities/bank_account.dart';
import 'package:finance_tracker/core/utils/currency_formatter.dart';

class AccountCard extends StatelessWidget {
  final BankAccount account;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const AccountCard({
    super.key,
    required this.account,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = account.totalBalance;
    final usableFraction = total > 0 ? account.usableAmount / total : 0.0;
    final savingsFraction = total > 0 ? account.savingsAmount / total : 0.0;
    final minimumFraction = total > 0 ? account.minimumBalance / total : 0.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner
            if (account.isBelowMinimum)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: theme.colorScheme.errorContainer,
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      'Below minimum balance!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (account.isNearMinimum)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.amber.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Approaching minimum balance',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.account_balance,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account.name,
                                style: theme.textTheme.titleMedium),
                            Text(account.bankName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline)),
                          ],
                        ),
                      ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: onDelete,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Total balance
                  Text(
                    CurrencyFormatter.format(account.totalBalance),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Balance partition bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          Flexible(
                            flex: (usableFraction * 100).round().clamp(1, 100),
                            child: Container(color: theme.colorScheme.primary),
                          ),
                          Flexible(
                            flex: (savingsFraction * 100).round().clamp(0, 100),
                            child: Container(color: Colors.green),
                          ),
                          Flexible(
                            flex: (minimumFraction * 100).round().clamp(0, 100),
                            child: Container(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Breakdown
                  _BalanceRow(
                    color: theme.colorScheme.primary,
                    label: 'Usable',
                    amount: account.usableAmount,
                  ),
                  const SizedBox(height: 4),
                  _BalanceRow(
                    color: Colors.green,
                    label: 'Savings',
                    amount: account.savingsAmount,
                  ),
                  const SizedBox(height: 4),
                  _BalanceRow(
                    color: theme.colorScheme.outline,
                    label: 'Min. Balance',
                    amount: account.minimumBalance,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;

  const _BalanceRow({
    required this.color,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const Spacer(),
        Text(
          CurrencyFormatter.format(amount),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
