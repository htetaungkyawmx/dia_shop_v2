import 'package:intl/intl.dart';

/// Shared formatting so prices and dates look the same everywhere.
class Format {
  const Format._();

  static final NumberFormat _thousands = NumberFormat.decimalPattern('en_US');

  /// 12400 -> "12,400 Ks"
  static String money(num amount) => '${_thousands.format(amount)} Ks';

  /// Signed, for ledger rows: -12400 -> "-12,400 Ks"
  static String signedMoney(num amount) {
    final sign = amount > 0 ? '+' : '';
    return '$sign${_thousands.format(amount)} Ks';
  }

  static String number(num value) => _thousands.format(value);

  static String date(DateTime value) => DateFormat('d MMM yyyy').format(value.toLocal());

  static String dateTime(DateTime value) => DateFormat('d MMM yyyy, h:mm a').format(value.toLocal());

  /// "2 hours ago" style, falling back to a date once it stops being useful.
  static String relative(DateTime value) {
    final diff = DateTime.now().difference(value.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(value);
  }
}
