import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_tracker/shared/ml/ml_providers.dart';
import 'package:finance_tracker/features/subscriptions/presentation/providers/subscription_providers.dart';
import 'package:finance_tracker/shared/ml/training_buffer.dart';
import 'package:finance_tracker/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:finance_tracker/features/accounts/presentation/providers/account_providers.dart';
import 'package:finance_tracker/features/budgets/presentation/providers/budget_providers.dart';
import 'package:finance_tracker/shared/database/app_database.dart';
import 'package:finance_tracker/core/utils/csv_exporter.dart';
import 'package:finance_tracker/core/utils/currency_formatter.dart';

// ─── Theme persistence ──────────────────────────────────────
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == 'light') {
      state = ThemeMode.light;
    } else if (value == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// ─── User name persistence ──────────────────────────────────
final userNameProvider = StateNotifierProvider<UserNameNotifier, String>((ref) {
  return UserNameNotifier();
});

class UserNameNotifier extends StateNotifier<String> {
  static const _key = 'user_name';

  UserNameNotifier() : super('') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key) ?? '';
  }

  Future<void> setName(String name) async {
    state = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name);
  }
}

// ─── Settings Page ──────────────────────────────────────────
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Profile Section
          Text('Profile',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const _UserNameTile(),
          ),
          const SizedBox(height: 32),

          // Appearance Section
          Text('Appearance',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.palette,
                          color: theme.colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'App Theme',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Auto'),
                        icon: Icon(Icons.auto_mode, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode, size: 16),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (set) =>
                        ref.read(themeModeProvider.notifier).setMode(set.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Currency Section
          Text('Currency',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          const _CurrencySelector(),
          const SizedBox(height: 32),

          // Subscriptions
          Text('Subscriptions',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.subscriptions,
                    color: theme.colorScheme.onSecondaryContainer),
              ),
              title: const Text('Manage Subscriptions'),
              subtitle: Consumer(
                builder: (context, ref, _) {
                  final total = ref.watch(monthlySubscriptionTotalProvider);
                  final subs =
                      ref.watch(subscriptionsProvider).valueOrNull ?? [];
                  return Text(
                      '${subs.length} active \u00b7 ${CurrencyFormatter.format(total)}/month');
                },
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/subscriptions'),
            ),
          ),
          const SizedBox(height: 32),

          // Budgets
          Text('Budgets',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pie_chart,
                    color: theme.colorScheme.onTertiaryContainer),
              ),
              title: const Text('Monthly Budgets'),
              subtitle: const Text('Set spending limits per category'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/budgets'),
            ),
          ),
          const SizedBox(height: 32),

          // Data Management
          Text('Data Management',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const _ExportCsvTile(),
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: theme.dividerColor.withValues(alpha: 0.5)),
                const _ClearDataTile(),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Machine Learning
          Text('Intelligence',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          const _MLStatusTile(),

          const SizedBox(height: 32),

          // About
          Center(
            child: Column(
              children: [
                Icon(Icons.account_balance_wallet,
                    size: 48,
                    color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Text(
                  'FinTrack',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'v1.0.0 \u00b7 On-Device ML Portfolio Project',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Currency Selector ──────────────────────────────────────
class _CurrencySelector extends ConsumerWidget {
  const _CurrencySelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCurrency = ref.watch(currencyProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.currency_exchange,
                    color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Display Currency',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CurrencyConfig.supportedCurrencies.map((currency) {
              final isSelected = currency.code == currentCurrency.code;
              return ChoiceChip(
                label: Text('${currency.symbol} ${currency.code}'),
                selected: isSelected,
                onSelected: (_) =>
                    ref.read(currencyProvider.notifier).setCurrency(currency),
                showCheckmark: false,
                selectedColor: theme.colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── ML Status Tile ─────────────────────────────────────────
class _MLStatusTile extends ConsumerWidget {
  const _MLStatusTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorizerAsync = ref.watch(categorizerProvider);
    final pendingSamples = ref.watch(pendingTrainingSamplesProvider);
    final theme = Theme.of(context);

    final isModelLoaded = categorizerAsync.valueOrNull != null;
    final pending = pendingSamples.valueOrNull ?? 0;
    final progress =
        (pending / TrainingBuffer.retrainThreshold).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          tilePadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isModelLoaded
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy,
              color: isModelLoaded
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          title: const Text('ML System Status',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            isModelLoaded ? 'Active & Learning' : 'Initializing...',
            style: TextStyle(
              color:
                  isModelLoaded ? Colors.green : theme.colorScheme.outline,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _StatusRow(
                    label: 'Generic Model',
                    status: isModelLoaded ? 'Loaded' : 'Unavailable',
                    icon: isModelLoaded ? Icons.check_circle : Icons.cancel,
                    color: isModelLoaded
                        ? Colors.green
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.model_training, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personalization Progress',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pending >= TrainingBuffer.retrainThreshold
                                  ? 'Ready to retrain'
                                  : '${TrainingBuffer.retrainThreshold - pending} samples until next retrain',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _StatusRow extends StatelessWidget {
  final String label;
  final String status;
  final IconData icon;
  final Color color;

  const _StatusRow({
    required this.label,
    required this.status,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(status,
            style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── User Name Tile ─────────────────────────────────────────
class _UserNameTile extends ConsumerStatefulWidget {
  const _UserNameTile();

  @override
  ConsumerState<_UserNameTile> createState() => _UserNameTileState();
}

class _UserNameTileState extends ConsumerState<_UserNameTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(userNameProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen<String>(userNameProvider, (_, next) {
      if (_controller.text != next) {
        _controller.text = next;
      }
    });

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child:
              Icon(Icons.person, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Enter your name',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (value) {
              ref.read(userNameProvider.notifier).setName(value.trim());
            },
          ),
        ),
      ],
    );
  }
}

// ─── Clear All Data Tile ─────────────────────────────────────
class _ClearDataTile extends ConsumerWidget {
  const _ClearDataTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.delete_forever,
            color: theme.colorScheme.onErrorContainer),
      ),
      title: const Text('Clear All Data'),
      subtitle: const Text('Delete all transactions, accounts, budgets & subscriptions'),
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Clear All Data?'),
            content: const Text(
              'This will permanently delete all transactions, accounts, budgets, and subscriptions. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete All'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;

        await AppDatabase.clearAllData();

        ref.invalidate(transactionsProvider);
        ref.invalidate(accountsProvider);
        ref.invalidate(subscriptionsProvider);
        ref.invalidate(budgetsProvider);
        ref.invalidate(pendingTrainingSamplesProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data cleared')),
          );
        }
      },
    );
  }
}

// ─── Export CSV Tile ─────────────────────────────────────────
class _ExportCsvTile extends ConsumerWidget {
  const _ExportCsvTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final transactions = transactionsAsync.valueOrNull ?? [];
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.download,
            color: theme.colorScheme.onSecondaryContainer),
      ),
      title: const Text('Export Data'),
      subtitle:
          Text('${transactions.length} transactions available for export'),
      enabled: transactions.isNotEmpty,
      onTap: () async {
        try {
          final path = await CsvExporter.export(transactions);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Exported to $path'),
                action: SnackBarAction(label: 'Open', onPressed: () {}),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Export failed: $e'),
                  backgroundColor: theme.colorScheme.error),
            );
          }
        }
      },
    );
  }
}
