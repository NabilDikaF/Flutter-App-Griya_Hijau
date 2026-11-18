import 'package:material_ui/material_ui.dart';
import 'app_colors.dart';

/// Skala tipografi Design System Figma ("Inter").
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  static const TextStyle h1 = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: AppColors.slate900,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.slate900,
    height: 1.2,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.slate900,
    height: 1.3,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.slate900,
    height: 1.4,
  );

  static const TextStyle bodyMedium15 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.slate900,
    height: 1.4,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle bodyNormal = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.slate600,
    height: 1.4,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.slate900,
    height: 1.3,
  );

  static const TextStyle inputLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.slate900,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.slate600,
    height: 1.3,
  );

  static const TextStyle captionRegular = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.slate500,
    height: 1.3,
  );
}
