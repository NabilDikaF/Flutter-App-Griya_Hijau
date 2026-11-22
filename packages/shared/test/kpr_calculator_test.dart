import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

void main() {
  group('KprCalculator', () {
    test('calculates standard monthly annuity installment correctly', () {
      // P = 850.000.000 - 20% (170.000.000) = 680.000.000
      // r = 6.5 / 1200 = 0.0054166667, n = 15 * 12 = 180
      // M ≈ 5.923.530
      final KprCalculationResult result = KprCalculator.calculate(
        propertyPrice: 850000000,
        dpPercent: 20,
        tenorYears: 15,
        annualInterestRate: 6.5,
      );

      expect(result.dpAmount, 170000000);
      expect(result.loanPrincipal, 680000000);
      expect(result.tenorMonths, 180);
      expect(result.monthlyInstallment, 5923530);
    });

    test('falls back to P / n when interest rate is 0%', () {
      // P = 600.000.000 - 20% = 480.000.000, n = 10 * 12 = 120 => M = 4.000.000
      final KprCalculationResult result = KprCalculator.calculate(
        propertyPrice: 600000000,
        dpPercent: 20,
        tenorYears: 10,
        annualInterestRate: 0,
      );

      expect(result.loanPrincipal, 480000000);
      expect(result.tenorMonths, 120);
      expect(result.monthlyInstallment, 4000000);
    });

    test('handles NaN, Infinity, negative infinity, and pow overflow without throwing', () {
      final KprCalculationResult nanInputs = KprCalculator.calculate(
        propertyPrice: 800000000,
        dpPercent: double.nan,
        tenorYears: 15,
        annualInterestRate: double.nan,
      );
      expect(nanInputs.dpPercent, 0.0);
      expect(nanInputs.annualInterestRate, 0.0);
      expect(nanInputs.monthlyInstallment, (800000000 / 180).round());

      final KprCalculationResult infRate = KprCalculator.calculate(
        propertyPrice: 800000000,
        dpPercent: double.infinity,
        tenorYears: 10,
        annualInterestRate: double.infinity,
      );
      expect(infRate.dpPercent, 99.0);
      expect(infRate.annualInterestRate, 0.0);
      expect(infRate.monthlyInstallment, (8000000 / 120).round());

      final KprCalculationResult negInf = KprCalculator.calculate(
        propertyPrice: 800000000,
        dpPercent: double.negativeInfinity,
        tenorYears: 0,
        annualInterestRate: double.negativeInfinity,
      );
      expect(negInf.dpPercent, 0.0);
      expect(negInf.tenorMonths, 12);
      expect(negInf.monthlyInstallment, (800000000 / 12).round());

      final KprCalculationResult powOverflow = KprCalculator.calculate(
        propertyPrice: 800000000,
        dpPercent: 20,
        tenorYears: 5000,
        annualInterestRate: 50,
      );
      expect(powOverflow.monthlyInstallment, greaterThan(0));
    });
  });

  group('KprCalculatorCard widget', () {
    testWidgets('displays mandatory disclaimer and updates installment when tenor changes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: KprCalculatorCard(propertyPrice: 850000000),
            ),
          ),
        ),
      );

      expect(find.text(CompanyConfig.kprDisclaimer), findsOneWidget);
      expect(find.text('Rp 5.923.530 / bln'), findsOneWidget);

      await tester.tap(find.text('20 Tahun'));
      await tester.pump();

      expect(find.text('Rp 5.069.897 / bln'), findsOneWidget);
    });
  });
}
