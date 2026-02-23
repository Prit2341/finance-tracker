import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_tracker/shared/ml/ml_providers.dart';
import 'package:finance_tracker/shared/ml/training_buffer.dart';
import 'package:finance_tracker/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:finance_tracker/core/utils/csv_exporter.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Card colors
    final cardColor = isDark
        ? const Color(0xFF1A2332)
        : theme.colorScheme.surfaceContainer;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.08);
    final sectionLabelColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.45);
    final accentBlue = const Color(0xFF3B82F6);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 8),

            // ── Header ──
            Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left,
                          color: accentBlue, size: 22),
                      Text(
                        'Back',
                        style: TextStyle(
                          color: accentBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Done button
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: accentBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Title + Avatar ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Settings',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 34,
                  ),
                ),
                const Spacer(),
                // Profile avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.brown.shade300,
                        Colors.brown.shade600,
                      ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── PREFERENCES section ──
            _SectionLabel(label: 'PREFERENCES', color: sectionLabelColor),
            const SizedBox(height: 12),

            // App Theme card
            _SettingsCard(
              cardColor: cardColor,
              borderColor: borderColor,
              child: Column(
                children: [
                  Row(
                    children: [
                      _IconCircle(
                        icon: Icons.palette_outlined,
                        color: accentBlue,
                        bgColor: accentBlue.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'App Theme',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ThemeSegmentedControl(ref: ref),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Export CSV card
            _SettingsCard(
              cardColor: cardColor,
              borderColor: borderColor,
              child: _ExportCsvRow(ref: ref),
            ),
            const SizedBox(height: 28),

            // ── ON-DEVICE INTELLIGENCE section ──
            _SectionLabel(
                label: 'ON-DEVICE INTELLIGENCE', color: sectionLabelColor),
            const SizedBox(height: 12),

            _MLCoreStatusCard(
              cardColor: cardColor,
              borderColor: borderColor,
              accentBlue: accentBlue,
            ),
            const SizedBox(height: 28),

            // ── About FinTrack card ──
            _SettingsCard(
              cardColor: cardColor,
              borderColor: borderColor,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'FinTrack',
                    applicationVersion: '0.1.0 Pre-Alpha',
                    applicationLegalese:
                        'On-Device ML Portfolio Project\n© 2025 FinTrack',
                  );
                },
                child: Row(
                  children: [
                    _IconCircle(
                      icon: Icons.info_outline,
                      color: accentBlue,
                      bgColor: accentBlue.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'About FinTrack',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.3),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Version footer ──
            Center(
              child: Column(
                children: [
                  Text(
                    'Version 0.1.0 Pre-Alpha',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ON-DEVICE ML PORTFOLIO PROJECT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.25),
                      letterSpacing: 1.5,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable Components ────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;
  final Widget child;

  const _SettingsCard({
    required this.cardColor,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _IconCircle({
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ─── Theme Segmented Control ────────────────────────────────
class _ThemeSegmentedControl extends ConsumerWidget {
  final WidgetRef ref;
  const _ThemeSegmentedControl({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF0F1722)
        : Colors.grey.shade200;
    final selectedBg = isDark
        ? const Color(0xFF2A3544)
        : Colors.white;
    final unselectedText = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.5);
    final selectedText = isDark ? Colors.white : Colors.black;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _ThemeOption(
            label: 'Light',
            isSelected: themeMode == ThemeMode.light,
            selectedBg: selectedBg,
            selectedText: selectedText,
            unselectedText: unselectedText,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setMode(ThemeMode.light),
          ),
          _ThemeOption(
            label: 'Auto',
            isSelected: themeMode == ThemeMode.system,
            selectedBg: selectedBg,
            selectedText: selectedText,
            unselectedText: unselectedText,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setMode(ThemeMode.system),
          ),
          _ThemeOption(
            label: 'Dark',
            isSelected: themeMode == ThemeMode.dark,
            selectedBg: selectedBg,
            selectedText: selectedText,
            unselectedText: unselectedText,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color selectedBg;
  final Color selectedText;
  final Color unselectedText;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.isSelected,
    required this.selectedBg,
    required this.selectedText,
    required this.unselectedText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? selectedText : unselectedText,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Export CSV Row ──────────────────────────────────────────
class _ExportCsvRow extends ConsumerWidget {
  final WidgetRef ref;
  const _ExportCsvRow({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final transactions = transactionsAsync.valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: transactions.isEmpty
          ? null
          : () async {
              try {
                final path = await CsvExporter.export(transactions);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exported to $path')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Export failed: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'csv',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Export CSV Data',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Icon(
            Icons.ios_share,
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.35),
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ─── ML Core Status Card ────────────────────────────────────
class _MLCoreStatusCard extends ConsumerStatefulWidget {
  final Color cardColor;
  final Color borderColor;
  final Color accentBlue;

  const _MLCoreStatusCard({
    required this.cardColor,
    required this.borderColor,
    required this.accentBlue,
  });

  @override
  ConsumerState<_MLCoreStatusCard> createState() => _MLCoreStatusCardState();
}

class _MLCoreStatusCardState extends ConsumerState<_MLCoreStatusCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categorizerAsync = ref.watch(categorizerProvider);
    final pendingSamples = ref.watch(pendingTrainingSamplesProvider);

    final isModelLoaded = categorizerAsync.valueOrNull != null;
    final pending = pendingSamples.valueOrNull ?? 0;
    final progress =
        (pending / TrainingBuffer.retrainThreshold).clamp(0.0, 1.0);
    final progressPercent = (progress * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        children: [
          // Header - always visible
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.accentBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings_suggest,
                      color: widget.accentBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ML Core Status',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isModelLoaded
                              ? 'System Optimized'
                              : 'Initializing...',
                          style: TextStyle(
                            color: isModelLoaded
                                ? const Color(0xFF10B981)
                                : theme.colorScheme.outline,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable body
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Divider(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                    height: 1,
                  ),
                  const SizedBox(height: 16),

                  // Auto-Categorizer
                  _MLRow(
                    title: 'Auto-Categorizer',
                    subtitle: isModelLoaded
                        ? 'Real-time labeling active'
                        : 'Model not loaded',
                    trailing: isModelLoaded
                        ? _StatusBadge(
                            label: 'ACTIVE',
                            color: const Color(0xFF10B981),
                            hasIcon: true,
                          )
                        : _StatusBadge(
                            label: 'INACTIVE',
                            color: theme.colorScheme.outline,
                            hasIcon: false,
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Learning Progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Learning Progress',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Buffering new merchant patterns',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.4)
                                        : Colors.black.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$progressPercent%',
                            style: TextStyle(
                              color: widget.accentBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(widget.accentBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Personalization
                  _MLRow(
                    title: 'Personalization',
                    subtitle: 'Last refined 2h ago',
                    trailing: _StatusBadge(
                      label: 'HIGHLY TAILORED',
                      color: widget.accentBlue,
                      hasIcon: false,
                      outlined: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Privacy notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All machine learning processing happens locally on your device. Your financial data never leaves this phone.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.black.withValues(alpha: 0.4),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

class _MLRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _MLRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool hasIcon;
  final bool outlined;

  const _StatusBadge({
    required this.label,
    required this.color,
    this.hasIcon = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasIcon) ...[
            Icon(Icons.check_circle, color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
