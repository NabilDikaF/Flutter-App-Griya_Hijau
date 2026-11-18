import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

/// Badge kategori properti (mis. `Komplek Perumahan`, `Ruko`).
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.white,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Badge status ketersediaan unit (`Tersedia`, `Dipesan`, `Terjual`).
class AvailabilityBadge extends StatelessWidget {
  const AvailabilityBadge({super.key, required this.status});

  final AvailabilityStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      AvailabilityStatus.available => (
          AppColors.emerald100,
          AppColors.emerald800,
        ),
      AvailabilityStatus.booked => (
          AppColors.warningBg,
          AppColors.warningText,
        ),
      AvailabilityStatus.sold => (
          AppColors.errorBg,
          AppColors.errorText,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        status.label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Badge tampilan jumlah dilihat (`Dilihat N kali`) secara read-only.
class ViewsBadge extends StatelessWidget {
  const ViewsBadge({super.key, required this.viewsCount, this.compact = false});

  final int viewsCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String formatted = AppFormatters.number(viewsCount);
    final String text = compact ? '$formatted x' : 'Dilihat $formatted kali';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.visibility_outlined,
          size: 14,
          color: AppColors.slate500,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.captionRegular.copyWith(
            color: AppColors.slate500,
          ),
        ),
      ],
    );
  }
}
