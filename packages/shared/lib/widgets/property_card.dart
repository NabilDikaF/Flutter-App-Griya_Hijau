import 'package:material_ui/material_ui.dart';

import '../models/property.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'property_badges.dart';

/// Kartu Properti sesuai komponen Figma `Kartu Properti`.
class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    required this.onTap,
    this.imageUrl,
  });

  final PropertySummary property;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 196,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _PropertyThumbnail(imageUrl: imageUrl),
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        CategoryBadge(label: property.categoryName),
                        AvailabilityBadge(status: property.availabilityStatus),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppFormatters.rupiah(property.price),
                    style: AppTypography.h3.copyWith(
                      color: AppColors.emerald600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    property.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sectionLabel.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.slate500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.district,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.captionRegular,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ViewsBadge(viewsCount: property.viewsCount, compact: true),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Divider(height: 1),
                  ),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      if (property.landArea != null)
                        _SpecChip(label: 'LT ${property.landArea} m²'),
                      if (property.buildingArea != null)
                        _SpecChip(label: 'LB ${property.buildingArea} m²'),
                      if (property.bedrooms != null)
                        _SpecChip(label: 'KT ${property.bedrooms}'),
                      if (property.bathrooms != null)
                        _SpecChip(label: 'KM ${property.bathrooms}'),
                    ],
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

class _PropertyThumbnail extends StatelessWidget {
  const _PropertyThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl;
    if (url == null || url.trim().isEmpty) {
      return const _ImagePlaceholder();
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _ImagePlaceholder(),
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? progress,
      ) {
        if (progress == null) return child;
        return const _ImagePlaceholder(showProgress: true);
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.showProgress = false});

  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.emerald50, AppColors.slate100],
        ),
      ),
      child: Center(
        child: showProgress
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.emerald500,
                ),
              )
            : const Icon(
                Icons.apartment_outlined,
                size: 48,
                color: AppColors.emerald600,
              ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.slate600),
      ),
    );
  }
}
