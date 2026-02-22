import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyConfig {
  final String symbol;
  final String code;
  final String locale;

  const CurrencyConfig({
    required this.symbol,
    required this.code,
    this.locale = 'en_US',
  });

  static const supportedCurrencies = [
    CurrencyConfig(symbol: '\$', code: 'USD'),
    CurrencyConfig(symbol: '\u20B9', code: 'INR', locale: 'en_IN'),
    CurrencyConfig(symbol: '\u20AC', code: 'EUR', locale: 'de_DE'),
    CurrencyConfig(symbol: '\u00A3', code: 'GBP', locale: 'en_GB'),
    CurrencyConfig(symbol: '\u00A5', code: 'JPY', locale: 'ja_JP'),
    CurrencyConfig(symbol: 'A\$', code: 'AUD', locale: 'en_AU'),
    CurrencyConfig(symbol: 'C\$', code: 'CAD', locale: 'en_CA'),
  ];
}

class CurrencyNotifier extends StateNotifier<CurrencyConfig> {
  static const _key = 'currency_code';

  CurrencyNotifier() : super(CurrencyConfig.supportedCurrencies.first) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'USD';
    state = CurrencyConfig.supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => CurrencyConfig.supportedCurrencies.first,
    );
  }

  Future<void> setCurrency(CurrencyConfig currency) async {
    state = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, currency.code);
  }
}

final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, CurrencyConfig>((ref) {
  return CurrencyNotifier();
});

class CurrencyFormatter {
  static CurrencyConfig _config =
      const CurrencyConfig(symbol: '\$', code: 'USD');

  static void updateConfig(CurrencyConfig config) {
    _config = config;
  }

  static String format(double amount) {
    final formatter = NumberFormat.currency(
      symbol: _config.symbol,
      decimalDigits: _config.code == 'JPY' ? 0 : 2,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount) {
    if (amount.abs() >= 1000000) {
      return '${_config.symbol}${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      return '${_config.symbol}${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }

  static String get symbol => _config.symbol;
}
