import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:finance_tracker/features/subscriptions/domain/entities/subscription.dart';
import 'package:finance_tracker/features/subscriptions/presentation/providers/subscription_providers.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/features/accounts/presentation/providers/account_providers.dart';
import 'package:finance_tracker/core/constants/app_constants.dart';
import 'package:finance_tracker/core/utils/currency_formatter.dart';

class AddSubscriptionPage extends ConsumerStatefulWidget {
  final Subscription? subscription;

  const AddSubscriptionPage({super.key, this.subscription});

  @override
  ConsumerState<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends ConsumerState<AddSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionCategory _category = TransactionCategory.entertainment;
  BillingCycle _billingCycle = BillingCycle.monthly;
  String? _selectedAccountId;
  DateTime _startDate = DateTime.now();

  bool get _isEditing => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    if (widget.subscription != null) {
      final sub = widget.subscription!;
      _nameController.text = sub.name;
      _amountController.text = sub.amount.toStringAsFixed(2);
      _notesController.text = sub.notes ?? '';
      _category = sub.category;
      _billingCycle = sub.billingCycle;
      _selectedAccountId = sub.accountId;
      _startDate = sub.startDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();

    if (_isEditing) {
      final updated = widget.subscription!.copyWith(
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text),
        category: _category,
        billingCycle: _billingCycle,
        accountId: _selectedAccountId,
        startDate: _startDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        updatedAt: now,
      );
      await ref.read(subscriptionsProvider.notifier).updateSubscription(updated);
    } else {
      final subscription = Subscription(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text),
        category: _category,
        billingCycle: _billingCycle,
        accountId: _selectedAccountId,
        startDate: _startDate,
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(subscriptionsProvider.notifier).add(subscription);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(accountsProvider);
    final accounts = accountsAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Subscription' : 'Add Subscription'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g., Netflix, Spotify',
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.subscriptions_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '${CurrencyFormatter.symbol} ',
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final amount = double.tryParse(v);
                        if (amount == null || amount <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Billing Cycle Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Billing Cycle',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<BillingCycle>(
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        segments: const [
                          ButtonSegment(value: BillingCycle.weekly, label: Text('Week')),
                          ButtonSegment(value: BillingCycle.monthly, label: Text('Month')),
                          ButtonSegment(value: BillingCycle.quarterly, label: Text('3 Mon')),
                          ButtonSegment(value: BillingCycle.yearly, label: Text('Year')),
                        ],
                        selected: {_billingCycle},
                        onSelectionChanged: (set) =>
                            setState(() => _billingCycle = set.first),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Category & Account Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TransactionCategory.values
                          .where((c) => c != TransactionCategory.salary &&
                              c != TransactionCategory.freelance &&
                              c != TransactionCategory.transfer)
                          .map((cat) {
                        final isSelected = cat == _category;
                        final color = AppConstants.categoryColors[cat] ??
                            theme.colorScheme.primary;
                        return FilterChip(
                          selected: isSelected,
                          label: Text(cat.displayName),
                          avatar: Icon(
                            AppConstants.categoryIcons[cat],
                            size: 16,
                            color: isSelected ? theme.colorScheme.onPrimary : color,
                          ),
                          selectedColor: color,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                          ),
                          checkmarkColor: theme.colorScheme.onPrimary,
                          onSelected: (_) => setState(() => _category = cat),
                        );
                      }).toList(),
                    ),
                    if (accounts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Linked Account',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedAccountId,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.account_balance),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          ...accounts.map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              )),
                        ],
                        onChanged: (v) => setState(() => _selectedAccountId = v),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date & Notes Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Date',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat.yMMMd().format(_startDate),
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'e.g., Family plan, shared with 3',
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.notes),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _save,
                icon: Icon(_isEditing ? Icons.save : Icons.check),
                label: Text(_isEditing ? 'Update Subscription' : 'Save Subscription'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
