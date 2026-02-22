import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:finance_tracker/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:finance_tracker/core/constants/app_constants.dart';

class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({super.key});

  @override
  ConsumerState<TransactionListPage> createState() =>
      _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  String _searchQuery = '';
  TransactionCategory? _categoryFilter;
  TransactionType? _typeFilter;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> _applyFilters(List<Transaction> transactions) {
    var filtered = transactions;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((t) =>
              t.merchant.toLowerCase().contains(query) ||
              (t.description?.toLowerCase().contains(query) ?? false) ||
              t.category.displayName.toLowerCase().contains(query))
          .toList();
    }

    if (_categoryFilter != null) {
      filtered =
          filtered.where((t) => t.category == _categoryFilter).toList();
    }

    if (_typeFilter != null) {
      filtered = filtered.where((t) => t.type == _typeFilter).toList();
    }

    return filtered;
  }

  String _dateGroupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txnDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(txnDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This Week';
    if (diff < 30) return 'This Month';
    if (date.year == now.year) return DateFormat.MMMM().format(date);
    return DateFormat.yMMMM().format(date);
  }

  bool get _hasActiveFilters =>
      _categoryFilter != null || _typeFilter != null;

  void _clearFilters() {
    setState(() {
      _categoryFilter = null;
      _typeFilter = null;
      _searchQuery = '';
      _searchController.clear();
      _showSearch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                style: theme.textTheme.titleMedium,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
              )
            : const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => context.push('/settings'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(Icons.person,
                    size: 20, color: theme.colorScheme.onPrimary),
              ),
            ),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text('Error: $error', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => ref.invalidate(transactionsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 64,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No transactions yet',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add your first transaction',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final filtered = _applyFilters(transactions);

          return LayoutBuilder(
            builder: (context, constraints) {
              final maxContentWidth =
                  constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
              final horizontalPadding =
                  (constraints.maxWidth - maxContentWidth) / 2 + 16;

              // Group by date
              final groups = <String, List<Transaction>>{};
              for (final txn in filtered) {
                final label = _dateGroupLabel(txn.date);
                groups.putIfAbsent(label, () => []).add(txn);
              }

              return CustomScrollView(
                slivers: [
                  // Filter chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 8, horizontalPadding, 4),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Type filters
                            _FilterChip(
                              label: 'Expense',
                              icon: Icons.arrow_downward,
                              selected:
                                  _typeFilter == TransactionType.expense,
                              onSelected: (sel) => setState(() =>
                                  _typeFilter = sel
                                      ? TransactionType.expense
                                      : null),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Income',
                              icon: Icons.arrow_upward,
                              selected:
                                  _typeFilter == TransactionType.income,
                              onSelected: (sel) => setState(() =>
                                  _typeFilter = sel
                                      ? TransactionType.income
                                      : null),
                            ),
                            const SizedBox(width: 8),
                            // Category filter dropdown
                            PopupMenuButton<TransactionCategory?>(
                              onSelected: (cat) =>
                                  setState(() => _categoryFilter = cat),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: null,
                                  child: Text('All Categories'),
                                ),
                                ...TransactionCategory.values.map(
                                  (cat) => PopupMenuItem(
                                    value: cat,
                                    child: Row(
                                      children: [
                                        Icon(
                                          AppConstants.categoryIcons[cat],
                                          size: 18,
                                          color: AppConstants
                                              .categoryColors[cat],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(cat.displayName),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              child: Chip(
                                avatar: Icon(
                                  _categoryFilter != null
                                      ? AppConstants
                                          .categoryIcons[_categoryFilter]
                                      : Icons.category,
                                  size: 16,
                                  color: _categoryFilter != null
                                      ? AppConstants
                                          .categoryColors[_categoryFilter]
                                      : null,
                                ),
                                label: Text(_categoryFilter?.displayName ??
                                    'Category'),
                                side: BorderSide(
                                  color: _categoryFilter != null
                                      ? theme.colorScheme.primary
                                      : theme.dividerColor,
                                ),
                              ),
                            ),
                            if (_hasActiveFilters) ...[
                              const SizedBox(width: 8),
                              ActionChip(
                                avatar: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear'),
                                onPressed: _clearFilters,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Results count
                  if (_hasActiveFilters || _searchQuery.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding, vertical: 4),
                        child: Text(
                          '${filtered.length} of ${transactions.length} transactions',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),

                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 48,
                                color: theme.colorScheme.outline),
                            const SizedBox(height: 16),
                            Text('No matching transactions',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...groups.entries.map((entry) {
                      return SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                  horizontalPadding, 16, horizontalPadding, 8),
                              child: Text(
                                entry.key,
                                style:
                                    theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final txn = entry.value[index];
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding,
                                    vertical: 2,
                                  ),
                                  child: TransactionTile(
                                    transaction: txn,
                                    onTap: () => context.push(
                                        '/edit-transaction',
                                        extra: txn),
                                    onDismissed: () {
                                      ref
                                          .read(transactionsProvider.notifier)
                                          .delete(txn.id);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Deleted ${txn.merchant}'),
                                          action: SnackBarAction(
                                            label: 'Undo',
                                            onPressed: () {
                                              ref
                                                  .read(transactionsProvider
                                                      .notifier)
                                                  .add(txn);
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                              childCount: entry.value.length,
                            ),
                          ),
                        ],
                      );
                    }),

                  const SliverPadding(
                      padding: EdgeInsets.only(bottom: 80)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
    );
  }
}
