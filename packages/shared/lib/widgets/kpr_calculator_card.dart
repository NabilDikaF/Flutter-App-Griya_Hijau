import 'package:material_ui/material_ui.dart';

import '../config/company_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import '../utils/kpr_calculator.dart';

/// Kartu simulasi KPR interaktif sesuai Desain Figma (`Kalkulator KPR`) & PRD 4.3.4.
class KprCalculatorCard extends StatefulWidget {
  const KprCalculatorCard({
    super.key,
    required this.propertyPrice,
  });

  final int propertyPrice;

  @override
  State<KprCalculatorCard> createState() => _KprCalculatorCardState();
}

class _KprCalculatorCardState extends State<KprCalculatorCard> {
  double _dpPercent = KprCalculator.defaultDpPercent;
  int _tenorYears = KprCalculator.defaultTenorYears;
  double _annualInterestRate = KprCalculator.defaultAnnualInterestRate;

  @override
  Widget build(BuildContext context) {
    final KprCalculationResult result = KprCalculator.calculate(
      propertyPrice: widget.propertyPrice,
      dpPercent: _dpPercent,
      tenorYears: _tenorYears,
      annualInterestRate: _annualInterestRate,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.calculate_outlined,
                    color: AppColors.emerald600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      Text('Simulasi Cicilan KPR', style: AppTypography.h3),
                      SizedBox(height: 2),
                      Text(
                        'Atur uang muka, tenor, dan asumsi bunga tahunan',
                        style: AppTypography.captionRegular,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _SummaryRow(
              label: 'Harga Properti',
              value: AppFormatters.rupiah(result.propertyPrice),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(
              label: 'Estimasi Pokok Pinjaman',
              value: AppFormatters.rupiah(result.loanPrincipal),
            ),
            const Divider(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Expanded(
                  child: Text('Uang Muka (DP)', style: AppTypography.inputLabel),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    '${_dpPercent.round()}% (${AppFormatters.rupiah(result.dpAmount)})',
                    textAlign: TextAlign.end,
                    style: AppTypography.inputLabel.copyWith(
                      color: AppColors.emerald800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _dpPercent,
              min: 5,
              max: 50,
              divisions: 9,
              label: '${_dpPercent.round()}%',
              activeColor: AppColors.emerald500,
              onChanged: (double value) {
                setState(() => _dpPercent = value.roundToDouble());
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('Tenor Pinjaman', style: AppTypography.inputLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: KprCalculator.defaultTenorOptions.map((int years) {
                final bool selected = years == _tenorYears;
                return ChoiceChip(
                  label: Text('$years Tahun'),
                  selected: selected,
                  labelStyle: AppTypography.caption.copyWith(
                    color: selected ? AppColors.white : AppColors.slate900,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: AppColors.emerald500,
                  backgroundColor: AppColors.white,
                  checkmarkColor: AppColors.white,
                  onSelected: (_) => setState(() => _tenorYears = years),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Asumsi Suku Bunga / Tahun',
                    style: AppTypography.inputLabel,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    '${_annualInterestRate.toStringAsFixed(1)}%',
                    textAlign: TextAlign.end,
                    style: AppTypography.inputLabel.copyWith(
                      color: AppColors.emerald800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _annualInterestRate,
              min: 0,
              max: 15,
              divisions: 30,
              label: '${_annualInterestRate.toStringAsFixed(1)}%',
              activeColor: AppColors.emerald500,
              onChanged: (double value) {
                setState(
                  () => _annualInterestRate = (value * 2).round() / 2.0,
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Estimasi cicilan per bulan',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.emerald200,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${AppFormatters.rupiah(result.monthlyInstallment)} / bln',
                    key: const ValueKey<String>('kpr_monthly_installment'),
                    style: AppTypography.h2.copyWith(
                      color: AppColors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'DP ${_dpPercent.round()}%, tenor $_tenorYears tahun (${result.tenorMonths} bln), '
                    'bunga ${_annualInterestRate.toStringAsFixed(1)}%',
                    style: AppTypography.captionRegular.copyWith(
                      color: AppColors.slate200,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.emerald200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.emerald800,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      CompanyConfig.kprDisclaimer,
                      style: AppTypography.captionRegular.copyWith(
                        color: AppColors.emerald950,
                        height: 1.45,
                      ),
                    ),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(child: Text(label, style: AppTypography.bodyNormal)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.sectionLabel.copyWith(color: AppColors.slate900),
          ),
        ),
      ],
    );
  }
}
