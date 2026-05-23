import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _currencyCompact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);
  static final _date = DateFormat('dd MMM yyyy');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final _month = DateFormat('MMM yyyy');
  static final _isoDate = DateFormat('yyyy-MM-dd');

  static String currency(num? amount) => _currency.format(amount ?? 0);
  static String currencyCompact(num? amount) => _currencyCompact.format(amount ?? 0);
  static String date(DateTime? d) => d == null ? '-' : _date.format(d);
  static String dateTime(DateTime? d) => d == null ? '-' : _dateTime.format(d);
  static String month(DateTime? d) => d == null ? '-' : _month.format(d);
  static String isoDate(DateTime? d) => d == null ? '' : _isoDate.format(d);

  static String quantity(num? q, {String unit = ''}) {
    final formatted = q == q?.toInt() ? q!.toInt().toString() : q?.toStringAsFixed(3) ?? '0';
    return unit.isEmpty ? formatted : '$formatted $unit';
  }

  static String percentage(num? p) => '${p?.toStringAsFixed(2) ?? '0'}%';

  static String invoiceStatus(String status) {
    return switch (status) {
      'DRAFT' => 'Draft',
      'SENT' => 'Sent',
      'PARTIAL' => 'Partial',
      'PAID' => 'Paid',
      'OVERDUE' => 'Overdue',
      'CANCELLED' => 'Cancelled',
      _ => status,
    };
  }

  static String paymentMode(String mode) {
    return switch (mode) {
      'CASH' => 'Cash',
      'CHEQUE' => 'Cheque',
      'BANK_TRANSFER' => 'Bank Transfer',
      'UPI' => 'UPI',
      'CARD' => 'Card',
      _ => 'Other',
    };
  }
}
