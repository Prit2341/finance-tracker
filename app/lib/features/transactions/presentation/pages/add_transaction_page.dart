import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:intl/intl.dart';
import 'package:finance_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:finance_tracker/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:finance_tracker/core/constants/app_constants.dart';
import 'package:finance_tracker/shared/ml/categorizer.dart';
import 'package:finance_tracker/shared/ml/ml_providers.dart';
import 'package:finance_tracker/features/accounts/presentation/providers/account_providers.dart';

import 'package:finance_tracker/core/utils/currency_formatter.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final Transaction? transaction;

  const AddTransactionPage({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _descriptionController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.other;
  DateTime _date = DateTime.now();
  String? _selectedAccountId;

  bool get _isEditing => widget.transaction != null;

  // ML categorization state
  List<CategoryPrediction> _suggestions = [];
  bool _wasAutoAssigned = false;
  bool _wasCorrected = false;
  TransactionCategory? _originalPrediction;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final txn = widget.transaction!;
      _amountController.text = txn.amount.toStringAsFixed(2);
      _merchantController.text = txn.merchant;
      _descriptionController.text = txn.description ?? '';
      _type = txn.type;
      _category = txn.category;
      _date = txn.date;
      _selectedAccountId = txn.accountId;
    }
    _merchantController.addListener(_onMerchantChanged);
  }

  @override
  void dispose() {
    _merchantController.removeListener(_onMerchantChanged);
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onMerchantChanged() {
    final merchant = _merchantController.text.trim();
    if (merchant.length >= 2) {
      _predictCategory(merchant);
    } else {
      setState(() {
        _suggestions = [];
        _wasAutoAssigned = false;
      });
    }
  }

  void _predictCategory(String merchant) {
    final categorizerAsync = ref.read(categorizerProvider);
    final categorizer = categorizerAsync.valueOrNull;
    if (categorizer == null) return;

    final predictions = categorizer.predict(merchant);
    if (predictions.isEmpty) return;

    setState(() {
      _suggestions = predictions;
      if (categorizer.shouldAutoAssign(predictions)) {
        _category = predictions.first.category;
        _wasAutoAssigned = true;
        _originalPrediction = predictions.first.category;
        _wasCorrected = false;
      } else {
        _wasAutoAssigned = false;
      }
    });
  }

  void _selectCategory(TransactionCategory cat) {
    setState(() {
      if (_wasAutoAssigned &&
          _originalPrediction != null &&
          cat != _originalPrediction) {
        _wasCorrected = true;
      }
      _category = cat;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final topConfidence =
        _suggestions.isNotEmpty ? _suggestions.first.confidence : null;

    var transaction = Transaction(
      id: _isEditing ? widget.transaction!.id : const Uuid().v4(),
      amount: double.parse(_amountController.text),
      merchant: _merchantController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      category: _category,
      date: _date,
      type: _type,
      predictedCategory: _originalPrediction,
      confidence: topConfidence,
      wasCorrected: _wasCorrected,
      accountId: _selectedAccountId,
    );

    // Run anomaly detection before saving (expenses only — model was trained on expense data)
    if (transaction.type == TransactionType.expense) {
      final detector = ref.read(anomalyDetectorProvider).valueOrNull;
      if (detector != null) {
        final anomalyResult = detector.detect(transaction);
        transaction = transaction.copyWith(
          isAnomaly: anomalyResult.isAnomaly,
          anomalyScore: anomalyResult.reconstructionError,
        );
      }
    }

    // Save or update transaction
    if (_isEditing) {
      await ref
          .read(transactionsProvider.notifier)
          .updateTransaction(transaction);
    } else {
      await ref.read(transactionsProvider.notifier).add(transaction);
    }

    // Record feedback for on-device retraining
    final buffer = ref.read(trainingBufferProvider);
    await buffer.record(transaction);

    // Check if retraining should be triggered
    final retrainer = ref.read(retrainerProvider);
    if (await retrainer.shouldRetrain()) {
      retrainer.retrain().then((result) {
        if (result.success) {
          ref.invalidate(categorizerProvider);
          ref.invalidate(pendingTrainingSamplesProvider);
        }
      });
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categorizerAsync = ref.watch(categorizerProvider);
    final hasML = categorizerAsync.valueOrNull != null;
    final accountsAsync = ref.watch(accountsProvider);
    final accounts = accountsAsync.valueOrNull ?? [];

    final cardColor = isDark ? const Color(0xFF1E293B) : theme.cardTheme.color;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.08);
    final labelColor =
        theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Transaction' : 'Add New Transaction',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Invisible spacer to center the title
                  const SizedBox(width: 50),
                ],
              ),
            ),

            // ─── Scrollable Content ──────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),

                      // ─── Type Toggle ─────────────────────────
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            _TypePill(
                              label: 'Expense',
                              isSelected:
                                  _type == TransactionType.expense,
                              onTap: () => setState(
                                  () => _type = TransactionType.expense),
                            ),
                            _TypePill(
                              label: 'Income',
                              isSelected:
                                  _type == TransactionType.income,
                              onTap: () => setState(
                                  () => _type = TransactionType.income),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ─── Amount ───────────────────────────────
                      Center(
                        child: Text(
                          'How much?',
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '\$',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IntrinsicWidth(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 80),
                              child: Theme(
                                data: theme.copyWith(
                                  inputDecorationTheme:
                                      const InputDecorationTheme(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                  ),
                                ),
                                child: TextFormField(
                                  controller: _amountController,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.15),
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    final amount = double.tryParse(value);
                                    if (amount == null || amount <= 0) {
                                      return 'Enter a valid amount';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ─── Account ──────────────────────────────
                      if (accounts.isNotEmpty) ...[
                        _SectionLabel(label: 'ACCOUNT'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedAccountId,
                            dropdownColor: cardColor,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: Icon(Icons.unfold_more,
                                color: labelColor, size: 20),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(
                                  'No account selected',
                                  style: TextStyle(color: labelColor),
                                ),
                              ),
                              ...accounts.map((a) =>
                                  DropdownMenuItem<String>(
                                    value: a.id,
                                    child: Text(
                                      '${a.name} (Available: ${CurrencyFormatter.format(a.usableAmount)})',
                                    ),
                                  )),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedAccountId = v),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ─── Merchant ─────────────────────────────
                      _SectionLabel(label: 'MERCHANT NAME'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Theme(
                                data: theme.copyWith(
                                  inputDecorationTheme:
                                      const InputDecorationTheme(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                  ),
                                ),
                                child: TextFormField(
                                  controller: _merchantController,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: 'e.g., Whole Foods Market',
                                    hintStyle:
                                        TextStyle(color: labelColor),
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 16),
                                  ),
                                  validator: (value) =>
                                      (value == null ||
                                              value.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                ),
                              ),
                            ),
                            if (hasML)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.my_location,
                                  color: theme.colorScheme.primary,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ─── ML Suggestion Chips ──────────────────
                      if (_suggestions.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 16,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children:
                                      _suggestions.take(3).map((pred) {
                                    final isFirst =
                                        pred == _suggestions.first;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap: () => _selectCategory(
                                            pred.category),
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isFirst
                                                ? theme
                                                    .colorScheme.primary
                                                    .withValues(
                                                        alpha: 0.2)
                                                : cardColor,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isFirst
                                                  ? theme
                                                      .colorScheme.primary
                                                  : borderColor,
                                            ),
                                          ),
                                          child: Text(
                                            '${pred.category.displayName} ${(pred.confidence * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              color: isFirst
                                                  ? theme
                                                      .colorScheme.primary
                                                  : theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(
                                                          alpha: 0.7),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ─── Auto-assigned Banner ─────────────────
                      if (_wasAutoAssigned &&
                          _suggestions.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 18,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Auto-assigned: ${_category.displayName} (${(_suggestions.first.confidence * 100).toStringAsFixed(0)}% confidence)',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ─── Date Picker ──────────────────────────
                      _SectionLabel(label: 'DATE'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 18, color: labelColor),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat.yMMMd().format(_date),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Category Grid ────────────────────────
                      _SectionLabel(label: 'SELECT CATEGORY'),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children:
                            TransactionCategory.values.map((cat) {
                          final isSelected = cat == _category;
                          final catColor =
                              AppConstants.categoryColors[cat] ??
                                  Colors.grey;

                          return GestureDetector(
                            onTap: () => _selectCategory(cat),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.15)
                                    : cardColor,
                                borderRadius:
                                    BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : borderColor,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    AppConstants
                                        .categoryIcons[cat],
                                    size: 28,
                                    color: isSelected
                                        ? theme.colorScheme
                                            .primary
                                        : catColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    cat.displayName
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? theme.colorScheme
                                              .primary
                                          : theme
                                              .colorScheme
                                              .onSurface
                                              .withValues(
                                                  alpha: 0.6),
                                      fontSize: 10,
                                      fontWeight:
                                          FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign:
                                        TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // ─── Note ─────────────────────────────────
                      _SectionLabel(label: 'NOTE (OPTIONAL)'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Theme(
                          data: theme.copyWith(
                            inputDecorationTheme:
                                const InputDecorationTheme(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                          child: TextFormField(
                            controller: _descriptionController,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Add a note...',
                              hintStyle:
                                  TextStyle(color: labelColor),
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 16),
                            ),
                            maxLines: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Save Button ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        _isEditing
                            ? 'Update Transaction'
                            : 'Save Transaction',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable Section Label ────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ─── Type Toggle Pill ──────────────────────────────────────
class _TypePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
