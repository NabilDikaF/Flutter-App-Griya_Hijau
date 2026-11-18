import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../data/customer_repository.dart';

/// Pilihan cepat rentang harga di bottom sheet filter katalog.
class _PriceRangePreset {
  const _PriceRangePreset({
    required this.label,
    required this.minPrice,
    required this.maxPrice,
  });

  final String label;
  final int? minPrice;
  final int? maxPrice;

  bool matches(int? min, int? max) => minPrice == min && maxPrice == max;
}

const List<_PriceRangePreset> _pricePresets = <_PriceRangePreset>[
  _PriceRangePreset(label: 'Semua Harga', minPrice: null, maxPrice: null),
  _PriceRangePreset(
    label: '< Rp 800 Juta',
    minPrice: null,
    maxPrice: 800000000,
  ),
  _PriceRangePreset(
    label: 'Rp 800 Jt - Rp 1,5 M',
    minPrice: 800000000,
    maxPrice: 1500000000,
  ),
  _PriceRangePreset(
    label: '> Rp 1,5 Miliar',
    minPrice: 1500000000,
    maxPrice: null,
  ),
];

/// Bottom sheet filter Daerah, Rentang Harga, & Status Unit sesuai Figma `1:1560`.
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.initialFilter,
    required this.locations,
  });

  final CatalogFilter initialFilter;
  final List<Location> locations;

  static Future<CatalogFilter?> show(
    BuildContext context, {
    required CatalogFilter initialFilter,
    required List<Location> locations,
  }) {
    return showModalBottomSheet<CatalogFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (_) => FilterBottomSheet(
        initialFilter: initialFilter,
        locations: locations,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late int? _locationId = widget.initialFilter.locationId;
  late int? _minPrice = widget.initialFilter.minPrice;
  late int? _maxPrice = widget.initialFilter.maxPrice;
  late AvailabilityStatus? _status = widget.initialFilter.status;
  String _locationSearch = '';

  @override
  Widget build(BuildContext context) {
    final List<Location> visibleLocations = widget.locations.where((Location l) {
      if (_locationSearch.trim().isEmpty) return true;
      final String q = _locationSearch.trim().toLowerCase();
      return l.district.toLowerCase().contains(q) ||
          l.city.toLowerCase().contains(q);
    }).toList(growable: false);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (BuildContext context, ScrollController scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Filter Daerah & Unit',
                        style: AppTypography.h3,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    const Text('Rentang Harga', style: AppTypography.sectionLabel),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _pricePresets.map((_PriceRangePreset preset) {
                        final bool selected =
                            preset.matches(_minPrice, _maxPrice);
                        return ChoiceChip(
                          label: Text(preset.label),
                          selected: selected,
                          selectedColor: AppColors.emerald500,
                          backgroundColor: AppColors.white,
                          checkmarkColor: AppColors.white,
                          labelStyle: AppTypography.caption.copyWith(
                            color: selected ? AppColors.white : AppColors.slate900,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _minPrice = preset.minPrice;
                              _maxPrice = preset.maxPrice;
                            });
                          },
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Status Ketersediaan',
                      style: AppTypography.sectionLabel,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Semua'),
                          selected: _status == null,
                          selectedColor: AppColors.emerald500,
                          backgroundColor: AppColors.white,
                          checkmarkColor: AppColors.white,
                          labelStyle: AppTypography.caption.copyWith(
                            color: _status == null
                                ? AppColors.white
                                : AppColors.slate900,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setState(() => _status = null),
                        ),
                        for (final AvailabilityStatus item
                            in AvailabilityStatus.values)
                          ChoiceChip(
                            label: Text(item.label),
                            selected: _status == item,
                            selectedColor: AppColors.emerald500,
                            backgroundColor: AppColors.white,
                            checkmarkColor: AppColors.white,
                            labelStyle: AppTypography.caption.copyWith(
                              color: _status == item
                                  ? AppColors.white
                                  : AppColors.slate900,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => setState(() => _status = item),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Pilih Daerah', style: AppTypography.sectionLabel),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      onChanged: (String value) {
                        setState(() => _locationSearch = value);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Cari kecamatan atau kota...',
                        prefixIcon:
                            Icon(Icons.search, color: AppColors.slate500),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _LocationOptionTile(
                      label: 'Semua daerah',
                      selected: _locationId == null,
                      onTap: () => setState(() => _locationId = null),
                    ),
                    for (final Location loc in visibleLocations)
                      _LocationOptionTile(
                        label: loc.displayName,
                        selected: _locationId == loc.id,
                        onTap: () => setState(() => _locationId = loc.id),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            widget.initialFilter.copyWith(
                              clearLocation: true,
                              clearMinPrice: true,
                              clearMaxPrice: true,
                              clearStatus: true,
                              offset: 0,
                            ),
                          );
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            widget.initialFilter.copyWith(
                              locationId: _locationId,
                              clearLocation: _locationId == null,
                              minPrice: _minPrice,
                              clearMinPrice: _minPrice == null,
                              maxPrice: _maxPrice,
                              clearMaxPrice: _maxPrice == null,
                              status: _status,
                              clearStatus: _status == null,
                              offset: 0,
                            ),
                          );
                        },
                        child: const Text('Terapkan Filter'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocationOptionTile extends StatelessWidget {
  const _LocationOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
        color: selected ? AppColors.emerald600 : AppColors.slate500,
      ),
      title: Text(
        label,
        style: AppTypography.bodyMedium15.copyWith(
          color: selected ? AppColors.emerald800 : AppColors.slate900,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}
