import 'package:intl/intl.dart';

final _currencyFormatter = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);

final _compactFormatter = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 0,
);

String formatCurrency(double value) => _currencyFormatter.format(value);

String formatCurrencyCompact(double value) {
  if (value >= 1000) {
    return 'R\$ ${(value / 1000).toStringAsFixed(1)}k';
  }
  return _compactFormatter.format(value);
}

String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy', 'pt_BR').format(date);
}

String formatDateShort(DateTime date) {
  return DateFormat('dd/MM', 'pt_BR').format(date);
}

String formatMonthYear(DateTime date) {
  return DateFormat('MMMM yyyy', 'pt_BR').format(date);
}

String formatMonthYearCapitalized(DateTime date) {
  final formatted = DateFormat('MMMM yyyy', 'pt_BR').format(date);
  return formatted[0].toUpperCase() + formatted.substring(1);
}

String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateTime(date.year, date.month, date.day);

  if (dateOnly == today) return 'Hoje';
  if (dateOnly == yesterday) return 'Ontem';
  return formatDate(date);
}