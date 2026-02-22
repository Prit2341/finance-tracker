import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:finance_tracker/features/budgets/domain/entities/budget.dart';
import 'package:finance_tracker/features/budgets/presentation/providers/budget_providers.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/core/constants/app_constants.dart';
import 'package:finance_tracker/core/utils/currency_formatter.dart';

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final spending = ref.watch(monthlySpendingByCategoryProvider);
    final totalLimit = ref.watch(totalBudgetLimitProvider);
    final totalSpent = ref.watch(totalBudgetSpentProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Budgets')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBudgetDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer
                          .withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.pie_chart,
                        size: 48, color: theme.colorScheme.tertiary),
                  ),
                  const SizedBox(height: 24),
                  Text('No Budgets Set',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Set monthly spending limits for each category to stay on track.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () =>
                        _showAddBudgetDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Set a Budget'),
                  ),
                ],
              ),
            );
          }

          final overallProgress =
              totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.5) : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Overview card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: overallProgress > 1.0
                        ? [theme.colorScheme.error, theme.colorScheme.errorContainer]
                        : [theme.colorScheme.primary, theme.colorScheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (overallProgress > 1.0
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary)
                          .withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'This Month',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(overallProgress * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${CurrencyFormatter.format(totalSpent)} of ${CurrencyFormatter.format(totalLimit)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: overallProgress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      totalLimit > totalSpent
                          ? '${CurrencyFormatter.format(totalLimit - totalSpent)} remaining'
                          : '${CurrencyFormatter.format(totalSpent - totalLimit)} over budget!',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('Category Budgets',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              ...budgets.map((budget) {
                final spent = spending[budget.category] ?? 0;
                final progress =
                    budget.limit > 0 ? (spent / budget.limit) : 0.0;
                final isOver = progress > 1.0;
                final catColor =
                    AppConstants.categoryColors[budget.category] ??
                        theme.colorScheme.primary;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Dismissible(
                    key: Key(budget.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Budget?'),
                          content: Text(
                              'Remove budget for ${budget.category.displayName}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ?? false;
                    },
                    onDismissed: (_) =>
                        ref.read(budgetsProvider.notifier).delete(budget.id),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.delete,
                          color: theme.colorScheme.onError),
                    ),
                    child: InkWell(
                      onTap: () => _showEditBudgetDialog(
                          context, ref, budget),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isOver
                                ? theme.colorScheme.error
                                    .withValues(alpha: 0.3)
                                : theme.dividerColor
                                    .withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        catColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    AppConstants
                                        .categoryIcons[budget.category],
                                    color: catColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        budget.category.displayName,
                                        style: theme
                                            .textTheme.titleMedium
                                            ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${CurrencyFormatter.format(spent)} of ${CurrencyFormatter.format(budget.limit)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme.colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isOver
                                        ? theme.colorScheme.error
                                        : progress > 0.8
                                            ? Colors.orange
                                            : catColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: theme.colorScheme
                                    .surfaceContainerHighest,
                                color: isOver
                                    ? theme.colorScheme.error
                                    : progress > 0.8
                                        ? Colors.orange
                                        : catColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context, WidgetRef ref) {
    final existingBudgets =
        ref.read(budgetsProvider).valueOrNull ?? [];
    final existingCategories =
        existingBudgets.map((b) => b.category).toSet();

    // Only expense categories, excluding already-budgeted ones
    final availableCategories = TransactionCategory.values
        .where((c) =>
            c != TransactionCategory.salary &&
            c != TransactionCategory.freelance &&
            c != TransactionCategory.transfer &&
            !existingCategories.contains(c))
        .toList();

    if (availableCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All categories already have budgets set')),
      );
      return;
    }

    _showBudgetForm(context, ref, availableCategories, null);
  }

  void _showEditBudgetDialog(
      BuildContext context, WidgetRef ref, Budget budget) {
    _showBudgetForm(context, ref, [budget.category], budget);
  }

  void _showBudgetForm(BuildContext context, WidgetRef ref,
      List<TransactionCategory> categories, Budget? existing) {
    final theme = Theme.of(context);
    final controller = TextEditingController(
      text: existing?.limit.toStringAsFixed(0) ?? '',
    );
    var selectedCategory = existing?.category ?? categories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing != null ? 'Edit Budget' : 'Set Budget',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  if (categories.length > 1) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = cat == selectedCategory;
                        final color =
                            AppConstants.categoryColors[cat] ??
                                theme.colorScheme.primary;
                        return ChoiceChip(
                          label: Text(cat.displayName),
                          avatar: Icon(
                            AppConstants.categoryIcons[cat],
                            size: 16,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : color,
                          ),
                          selected: isSelected,
                          selectedColor: color,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : null,
                          ),
                          showCheckmark: false,
                          onSelected: (_) => setModalState(
                              () => selectedCategory = cat),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Row(
                      children: [
                        Icon(
                          AppConstants.categoryIcons[selectedCategory],
                          color: AppConstants
                              .categoryColors[selectedCategory],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          selectedCategory.displayName,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monthly Limit',
                      prefixText: '${CurrencyFormatter.symbol} ',
                      prefixStyle: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final amount = double.tryParse(controller.text);
                      if (amount == null || amount <= 0) return;
                      final now = DateTime.now();
                      if (existing != null) {
                        ref
                            .read(budgetsProvider.notifier)
                            .updateBudget(existing.copyWith(
                              limit: amount,
                              updatedAt: now,
                            ));
                      } else {
                        ref.read(budgetsProvider.notifier).add(Budget(
                              id: const Uuid().v4(),
                              category: selectedCategory,
                              limit: amount,
                              createdAt: now,
                              updatedAt: now,
                            ));
                      }
                      Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Text(
                        existing != null ? 'Update' : 'Set Budget'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
