import 'package:intl/intl.dart';

/// Utilitas pemformatan mata uang Rupiah, angka ribuan, dan tanggal Indonesia.
abstract final class AppFormatters {
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _numberFormatter =
      NumberFormat.decimalPattern('id_ID');

  static const List<String> _monthsShort = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ags',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Memformat nominal ke format Rupiah tanpa desimal, mis. `Rp 850.000.000`.
  static String rupiah(int amount) => _currencyFormatter.format(amount);

  /// Memformat angka ribuan dengan titik pemisah lokal Indonesia, mis. `1.240`.
  static String number(int value) => _numberFormatter.format(value);

  /// Memformat tanggal singkat Indonesia, mis. `14 Nov 2026`.
  static String date(DateTime value) {
    final DateTime local = value.toLocal();
    final String month = _monthsShort[local.month - 1];
    return '${local.day} $month ${local.year}';
  }

  /// Memformat tanggal dan waktu WIB, mis. `14 Nov 2026, 10:00 WIB`.
  static String dateTime(DateTime value) {
    final DateTime local = value.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${date(local)}, $hour:$minute WIB';
  }
}
