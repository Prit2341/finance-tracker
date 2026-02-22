import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:finance_tracker/features/accounts/domain/entities/bank_account.dart';
import 'package:finance_tracker/features/accounts/presentation/providers/account_providers.dart';

class AddAccountPage extends ConsumerStatefulWidget {
  const AddAccountPage({super.key});

  @override
  ConsumerState<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends ConsumerState<AddAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _totalBalanceController = TextEditingController();
  final _usableController = TextEditingController();
  final _savingsController = TextEditingController();
  final _minimumController = TextEditingController();

  String? _partitionError;

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _totalBalanceController.dispose();
    _usableController.dispose();
    _savingsController.dispose();
    _minimumController.dispose();
    super.dispose();
  }

  void _validatePartitions() {
    final total = double.tryParse(_totalBalanceController.text) ?? 0;
    final usable = double.tryParse(_usableController.text) ?? 0;
    final savings = double.tryParse(_savingsController.text) ?? 0;
    final minimum = double.tryParse(_minimumController.text) ?? 0;
    final sum = usable + savings + minimum;

    setState(() {
      if (total <= 0) {
        _partitionError = null;
      } else if ((sum - total).abs() > 0.01) { // Floating point tolerance
        if (sum > total) {
           _partitionError =
            'Partitions (\$${sum.toStringAsFixed(2)}) exceed total (\$${total.toStringAsFixed(2)})';
        } else {
          final diff = total - sum;
          _partitionError =
              '\$${diff.toStringAsFixed(2)} unallocated — partitions must equal total balance';
        }
      } else {
        _partitionError = null;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final total = double.parse(_totalBalanceController.text);
    final usable = double.parse(_usableController.text);
    final savings = double.parse(_savingsController.text);
    final minimum = double.parse(_minimumController.text);

    if ((usable + savings + minimum - total).abs() > 0.01) {
      _validatePartitions();
      return;
    }

    final now = DateTime.now();
    final account = BankAccount(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      bankName: _bankNameController.text.trim(),
      totalBalance: total,
      usableAmount: usable,
      savingsAmount: savings,
      minimumBalance: minimum,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(accountsProvider.notifier).add(account);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Bank Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Info Card
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
                    Text('Account Details', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Account Nickname',
                        hintText: 'e.g., Primary Savings',
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.label_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: InputDecoration(
                        labelText: 'Bank Name',
                        hintText: 'e.g., Chase, Wells Fargo',
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.account_balance),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Balance & Partitions Card
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
                    Row(
                      children: [
                        Icon(Icons.pie_chart_outline, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text('Balance Configuration', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Define how your total balance is allocated.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 24),
                    
                    TextFormField(
                      controller: _totalBalanceController,
                      decoration: InputDecoration(
                        labelText: 'Total Current Balance',
                        prefixText: '\$ ',
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _validatePartitions(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    Text('Partitions', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    
                    // Usable
                    _PartitionField(
                      controller: _usableController,
                      label: 'Usable Amount',
                      helper: 'For daily spending',
                      color: theme.colorScheme.primary,
                      onChanged: _validatePartitions,
                    ),
                    const SizedBox(height: 12),
                    
                    // Savings
                    _PartitionField(
                      controller: _savingsController,
                      label: 'Savings Amount',
                      helper: 'Set aside',
                      color: Colors.green,
                      onChanged: _validatePartitions,
                    ),
                    const SizedBox(height: 12),
                    
                    // Minimum
                    _PartitionField(
                      controller: _minimumController,
                      label: 'Minimum Balance',
                      helper: 'Bank requirement',
                      color: theme.colorScheme.outline,
                      onChanged: _validatePartitions,
                    ),
                  ],
                ),
              ),
              
              if (_partitionError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _partitionError!,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Save Account'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class _PartitionField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String helper;
  final Color color;
  final VoidCallback onChanged;

  const _PartitionField({
    required this.controller,
    required this.label,
    required this.helper,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(Icons.circle, size: 12, color: color),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        prefixText: '\$ ',
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (double.tryParse(v) == null) return 'Invalid';
        return null;
      },
    );
  }
}
