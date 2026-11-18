import 'dart:math' as math;

/// Hasil perhitungan simulasi cicilan KPR bulanan.
class KprCalculationResult {
  const KprCalculationResult({
    required this.propertyPrice,
    required this.dpPercent,
    required this.dpAmount,
    required this.loanPrincipal,
    required this.tenorYears,
    required this.tenorMonths,
    required this.annualInterestRate,
    required this.monthlyInstallment,
  });

  final int propertyPrice;
  final double dpPercent;
  final int dpAmount;
  final int loanPrincipal;
  final int tenorYears;
  final int tenorMonths;
  final double annualInterestRate;
  final int monthlyInstallment;
}

/// Kalkulator simulasi KPR dengan rumus anuitas standar perbankan.
///
/// Rumus sesuai PRD Bagian 4.3.4:
/// - `P = Harga Properti - Estimasi DP`
/// - `r = Bunga Tahunan (%) / (12 * 100)`
/// - `n = Tenor (tahun) * 12`
/// - Jika `r == 0`, `M = P / n`
/// - Selain itu, `M = P * (r * (1 + r)^n) / ((1 + r)^n - 1)`
abstract final class KprCalculator {
  static const List<int> defaultTenorOptions = <int>[5, 10, 15, 20, 25];
  static const double defaultDpPercent = 20;
  static const int defaultTenorYears = 15;
  static const double defaultAnnualInterestRate = 6.5;

  static KprCalculationResult calculate({
    required int propertyPrice,
    double dpPercent = defaultDpPercent,
    int tenorYears = defaultTenorYears,
    double annualInterestRate = defaultAnnualInterestRate,
  }) {
    final int safePrice = math.max(0, propertyPrice);
    final double safeDpPercent = dpPercent.clamp(0.0, 99.0).toDouble();
    final int safeTenorYears = math.max(1, tenorYears);
    final double safeAnnualRate = math.max(0.0, annualInterestRate);

    final int dpAmount = (safePrice * (safeDpPercent / 100.0)).round();
    final int loanPrincipal = math.max(0, safePrice - dpAmount);
    final int tenorMonths = safeTenorYears * 12;
    final double monthlyRate = safeAnnualRate / (12.0 * 100.0);

    final int monthlyInstallment;
    if (loanPrincipal == 0) {
      monthlyInstallment = 0;
    } else if (monthlyRate <= 0) {
      monthlyInstallment = (loanPrincipal / tenorMonths).round();
    } else {
      final num powFactor = math.pow(1.0 + monthlyRate, tenorMonths);
      final double numerator = monthlyRate * powFactor.toDouble();
      final double denominator = powFactor.toDouble() - 1.0;
      monthlyInstallment =
          denominator <= 0 ? 0 : (loanPrincipal * (numerator / denominator)).round();
    }

    return KprCalculationResult(
      propertyPrice: safePrice,
      dpPercent: safeDpPercent,
      dpAmount: dpAmount,
      loanPrincipal: loanPrincipal,
      tenorYears: safeTenorYears,
      tenorMonths: tenorMonths,
      annualInterestRate: safeAnnualRate,
      monthlyInstallment: monthlyInstallment,
    );
  }
}
