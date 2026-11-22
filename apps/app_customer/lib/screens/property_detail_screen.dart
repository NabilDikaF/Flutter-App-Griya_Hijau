import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared/shared.dart';

import '../core/env_config.dart';
import '../core/external_launcher.dart';
import '../data/customer_repository.dart';
import '../widgets/customer_scaffold.dart';

/// Layar Detail Properti (`/properti/:slug`) sesuai Figma `1:1854` & Tugas 2.3–2.5.
class PropertyDetailScreen extends ConsumerStatefulWidget {
  const PropertyDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<PropertyDetailScreen> createState() =>
      _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  final PageController _galleryController = PageController();
  int _currentSlide = 0;
  bool _isLoading = true;
  Object? _error;
  Property? _property;
  int? _viewsCount;
  int? _recordedPropertyId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadProperty);
  }

  @override
  void didUpdateWidget(covariant PropertyDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      _recordedPropertyId = null;
      _currentSlide = 0;
      _loadProperty();
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _loadProperty() async {
    final CustomerRepository repository = ref.read(customerRepositoryProvider);
    setState(() {
      _isLoading = true;
      _error = null;
    });

    Property? fetched;
    try {
      fetched = await repository.getPropertyBySlug(widget.slug);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
      return;
    }

    final Property? visibleProperty = (fetched != null &&
            fetched.isPublished &&
            (fetched.category?.isActive ?? false))
        ? fetched
        : null;

    if (!mounted) return;
    setState(() {
      _property = visibleProperty;
      _viewsCount = visibleProperty?.viewsCount;
      _isLoading = false;
    });

    if (visibleProperty != null && _recordedPropertyId != visibleProperty.id) {
      _recordedPropertyId = visibleProperty.id;
      try {
        final int? updatedCount =
            await repository.recordPropertyView(visibleProperty.id);
        if (mounted && updatedCount != null) {
          setState(() => _viewsCount = updatedCount);
        }
      } catch (_) {
        // Kegagalan pencatatan view tidak boleh menggagalkan tampilan detail properti.
      }
    }
  }

  void _openLightbox(List<String?> imageUrls, int initialIndex) {
    if (imageUrls.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _FullscreenGalleryDialog(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Property? raw = _property;
    final Property? property = (raw != null &&
            raw.isPublished &&
            (raw.category?.isActive ?? false))
        ? raw
        : null;
    final CustomerRepository repository = ref.watch(customerRepositoryProvider);

    return CustomerScaffold(
      currentPath: '/properti/${Uri.encodeComponent(widget.slug)}',
      title: property?.title ?? 'Detail Properti',
      showBackButton: true,
      bottomNavigationBar: property == null
          ? null
          : _StickyBookingBar(
              property: property,
              onBookingPressed: () => context.push(
                '/properti/${Uri.encodeComponent(property.slug)}/booking',
                extra: property,
              ),
            ),
      body: _buildBody(property, repository),
    );
  }

  Widget _buildBody(Property? property, CustomerRepository repository) {
    if (_isLoading) {
      return const AsyncStateView.loading(message: 'Memuat detail properti...');
    }
    if (_error != null) {
      return AsyncStateView.error(onRetry: _loadProperty);
    }
    if (property == null) {
      return AsyncStateView.empty(
        title: 'Properti tidak ditemukan',
        message: 'Unit mungkin sudah dihapus atau belum dipublikasikan.',
        onRetry: () => context.go('/katalog'),
      );
    }

    final List<String?> imageUrls = property.images
        .map((PropertyImage img) => repository.resolveImageUrl(img.imagePath))
        .toList(growable: false);
    final int slideCount = imageUrls.isEmpty ? 1 : imageUrls.length;
    final int viewsCount = _viewsCount ?? property.viewsCount;

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        _buildGallery(imageUrls, slideCount),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  CategoryBadge(label: property.category!.name),
                  AvailabilityBadge(status: property.availabilityStatus),
                  ViewsBadge(viewsCount: viewsCount),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(property.title, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.slate500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      property.location?.displayName ?? '-',
                      style: AppTypography.bodyNormal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.emerald200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Harga Indikatif',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.emerald800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppFormatters.rupiah(property.price),
                      style: AppTypography.h2.copyWith(
                        color: AppColors.emerald600,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('Spesifikasi Unit', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.md),
              _SpecificationsGrid(property: property),
              const SizedBox(height: AppSpacing.xl),
              const Text('Deskripsi & Alamat', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        property.description ??
                            'Belum ada deskripsi tambahan untuk unit ini.',
                        style: AppTypography.bodyMedium15,
                      ),
                      if (property.addressDetail != null &&
                          property.addressDetail!.trim().isNotEmpty) ...<Widget>[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Divider(height: 1),
                        ),
                        Text(
                          'Alamat Lengkap',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.slate500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          property.addressDetail!,
                          style: AppTypography.bodyNormal.copyWith(
                            color: AppColors.slate900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              KprCalculatorCard(propertyPrice: property.price),
              const SizedBox(height: AppSpacing.xl),
              const Text('Lokasi & Peta', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.md),
              _LocationSection(property: property),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
        const CustomerFooter(),
      ],
    );
  }

  Widget _buildGallery(List<String?> imageUrls, int slideCount) {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PageView.builder(
            controller: _galleryController,
            itemCount: slideCount,
            onPageChanged: (int index) {
              setState(() => _currentSlide = index);
            },
            itemBuilder: (BuildContext context, int index) {
              final String? url = imageUrls.isEmpty ? null : imageUrls[index];
              return GestureDetector(
                onTap: url != null ? () => _openLightbox(imageUrls, index) : null,
                child: url != null
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _GalleryPlaceholder(),
                      )
                    : const _GalleryPlaceholder(),
              );
            },
          ),
          Positioned(
            bottom: AppSpacing.md,
            right: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.slate900.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
              child: Text(
                '${_currentSlide + 1} / $slideCount',
                style: AppTypography.caption.copyWith(color: AppColors.white),
              ),
            ),
          ),
          if (imageUrls.any((String? u) => u != null))
            Positioned(
              bottom: AppSpacing.md,
              left: AppSpacing.md,
              child: InkWell(
                onTap: () => _openLightbox(imageUrls, _currentSlide),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.slate900.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.zoom_out_map,
                        size: 14,
                        color: AppColors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Perbesar',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GalleryPlaceholder extends StatelessWidget {
  const _GalleryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.emerald100, AppColors.slate200],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(
              Icons.apartment_outlined,
              size: 56,
              color: AppColors.emerald800,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Foto Unit Properti',
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenGalleryDialog extends StatelessWidget {
  const _FullscreenGalleryDialog({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String?> imageUrls;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final List<String> validUrls = imageUrls.whereType<String>().toList();
    final PageController controller = PageController(
      initialPage: initialIndex.clamp(0, validUrls.length - 1),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
        shape: const Border(),
        title: const Text('Galeri Properti'),
      ),
      body: PhotoViewGallery.builder(
        pageController: controller,
        itemCount: validUrls.length,
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(validUrls[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.5,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.white,
                size: 48,
              ),
            ),
          );
        },
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}

class _SpecificationsGrid extends StatelessWidget {
  const _SpecificationsGrid({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final List<({String label, String value, IconData icon})> items =
        <({String label, String value, IconData icon})>[
      (
        label: 'Luas Tanah',
        value: property.landArea != null ? '${property.landArea} m²' : '-',
        icon: Icons.straighten,
      ),
      (
        label: 'Luas Bangunan',
        value:
            property.buildingArea != null ? '${property.buildingArea} m²' : '-',
        icon: Icons.home_work_outlined,
      ),
      (
        label: 'Kamar Tidur',
        value: property.bedrooms?.toString() ?? '-',
        icon: Icons.bed_outlined,
      ),
      (
        label: 'Kamar Mandi',
        value: property.bathrooms?.toString() ?? '-',
        icon: Icons.bathtub_outlined,
      ),
      (
        label: 'Jumlah Lantai',
        value: property.floors?.toString() ?? '-',
        icon: Icons.layers_outlined,
      ),
      (
        label: 'Daya Listrik',
        value: property.electricity ?? '-',
        icon: Icons.bolt_outlined,
      ),
      (
        label: 'Sertifikat',
        value: property.certificateType ?? '-',
        icon: Icons.verified_outlined,
      ),
      (
        label: 'Status Unit',
        value: property.availabilityStatus.label,
        icon: Icons.info_outline,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.15,
      ),
      itemBuilder: (BuildContext context, int index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(
            children: <Widget>[
              Icon(item.icon, size: 20, color: AppColors.emerald600),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.captionRegular,
                    ),
                    Text(
                      item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sectionLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final double? lat = property.latitude;
    final double? lng = property.longitude;
    final bool hasCoords = lat != null && lng != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: hasCoords && EnvConfig.hasMapsApiKey
                  ? SizedBox(
                      height: 200,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(lat, lng),
                          zoom: 15,
                        ),
                        markers: <Marker>{
                          Marker(
                            markerId: MarkerId('property_${property.id}'),
                            position: LatLng(lat, lng),
                            infoWindow: InfoWindow(title: property.title),
                          ),
                        },
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 180),
                      child: Container(
                        color: AppColors.emerald50,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.map_outlined,
                              size: 40,
                              color: AppColors.emerald600,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              property.location?.displayName ?? 'Lokasi Properti',
                              textAlign: TextAlign.center,
                              style: AppTypography.sectionLabel,
                            ),
                            if (hasCoords) ...<Widget>[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Koordinat: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                                textAlign: TextAlign.center,
                                style: AppTypography.captionRegular,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'Peta tertanam aktif setelah Google Maps API Key ditambahkan.',
                              textAlign: TextAlign.center,
                              style: AppTypography.captionRegular,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (property.addressDetail != null &&
                property.addressDetail!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(property.addressDetail!, style: AppTypography.bodyNormal),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => ExternalLauncher.openGoogleMaps(
                context,
                googleMapsUrl: property.googleMapsUrl,
                latitude: lat,
                longitude: lng,
              ),
              icon: const Icon(Icons.directions_outlined, size: 18),
              label: const Text('Petunjuk Arah (Buka di Google Maps)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyBookingBar extends StatelessWidget {
  const _StickyBookingBar({
    required this.property,
    required this.onBookingPressed,
  });

  final Property property;
  final VoidCallback onBookingPressed;

  @override
  Widget build(BuildContext context) {
    final bool canBook =
        property.availabilityStatus == AvailabilityStatus.available;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.slate200)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Harga', style: AppTypography.captionRegular),
                  Text(
                    AppFormatters.rupiah(property.price),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sectionLabel.copyWith(
                      color: AppColors.emerald600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: canBook ? onBookingPressed : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  canBook
                      ? 'Booking / Jadwalkan Survei'
                      : 'Unit ${property.availabilityStatus.label}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
