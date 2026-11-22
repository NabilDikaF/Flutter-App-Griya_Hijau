import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../data/customer_repository.dart';
import '../widgets/customer_scaffold.dart';
import '../widgets/filter_bottom_sheet.dart';

/// Layar Katalog Properti (`/katalog`) sesuai Figma `1:1600` & Tugas 2.2.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    super.key,
    this.initialKeyword = '',
    this.initialCategoryId,
    this.initialLocationId,
  });

  final String initialKeyword;
  final int? initialCategoryId;
  final int? initialLocationId;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialKeyword,
  );
  Timer? _debounce;

  late CatalogFilter _filter = CatalogFilter(
    keyword: widget.initialKeyword,
    categoryId: widget.initialCategoryId,
    locationId: widget.initialLocationId,
  );

  bool _isLoading = true;
  bool _isLoadingMore = false;
  Object? _error;
  List<PropertySummary> _items = const <PropertySummary>[];
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _runSearch(resetPagination: true));
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialKeyword != widget.initialKeyword ||
        oldWidget.initialCategoryId != widget.initialCategoryId ||
        oldWidget.initialLocationId != widget.initialLocationId) {
      _searchController.text = widget.initialKeyword;
      _filter = CatalogFilter(
        keyword: widget.initialKeyword,
        categoryId: widget.initialCategoryId,
        locationId: widget.initialLocationId,
      );
      _runSearch(resetPagination: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onKeywordChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: CompanyConfig.searchDebounceMs),
      () {
        if (!mounted) return;
        setState(() {
          _filter = _filter.copyWith(keyword: value, offset: 0);
        });
        _runSearch(resetPagination: true);
      },
    );
  }

  Future<void> _runSearch({required bool resetPagination}) async {
    final CustomerRepository repository = ref.read(customerRepositoryProvider);
    final int nextOffset = resetPagination ? 0 : _items.length;
    final CatalogFilter queryFilter = _filter.copyWith(offset: nextOffset);

    setState(() {
      if (resetPagination) {
        _isLoading = true;
        _error = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final CatalogSearchResult result =
          await repository.searchProperties(queryFilter);
      if (!mounted) return;
      setState(() {
        _items = resetPagination
            ? result.items
            : <PropertySummary>[..._items, ...result.items];
        _totalCount = result.totalCount;
        _isLoading = false;
        _isLoadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _openFilterSheet(List<Location> locations) async {
    final CatalogFilter? updated = await FilterBottomSheet.show(
      context,
      initialFilter: _filter,
      locations: locations,
    );
    if (updated == null || !mounted) return;
    setState(() => _filter = updated);
    await _runSearch(resetPagination: true);
  }

  void _resetAllFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _filter = const CatalogFilter();
    });
    _runSearch(resetPagination: true);
  }

  @override
  Widget build(BuildContext context) {
    final CustomerRepository repository = ref.watch(customerRepositoryProvider);
    final AsyncValue<CustomerBootstrapData> bootstrapAsync =
        ref.watch(customerBootstrapProvider);
    final List<PropertyCategory> categories = bootstrapAsync.asData?.value.categories ??
        (repository.isUsingLocalSeeder
            ? SeedData.categories
            : const <PropertyCategory>[]);
    final List<Location> locations = bootstrapAsync.asData?.value.locations ??
        (repository.isUsingLocalSeeder
            ? SeedData.locations
            : const <Location>[]);

    return CustomerScaffold(
      currentPath: '/katalog',
      title: 'Katalog Properti',
      body: RefreshIndicator(
        onRefresh: () => _runSearch(resetPagination: true),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _buildHeaderAndControls(categories, locations),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildActiveFilterSummary(locations),
                  if (_isLoading)
                    const AsyncStateView.loading(
                      message: 'Mencari properti terbaik...',
                    )
                  else if (_error != null)
                    AsyncStateView.error(
                      onRetry: () => _runSearch(resetPagination: true),
                    )
                  else if (_items.isEmpty)
                    AsyncStateView.empty(
                      title: 'Tidak ada properti ditemukan',
                      message:
                          'Coba ubah kata kunci, kategori, daerah, atau rentang harga.',
                      onRetry: _resetAllFilters,
                    )
                  else ...<Widget>[
                    for (final PropertySummary item in _items) ...<Widget>[
                      PropertyCard(
                        property: item,
                        imageUrl: repository.resolveImageUrl(
                          item.primaryImagePath,
                        ),
                        onTap: () => context.push(
                          '/properti/${Uri.encodeComponent(item.slug)}',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (_items.length < _totalCount)
                      OutlinedButton(
                        onPressed: _isLoadingMore
                            ? null
                            : () => _runSearch(resetPagination: false),
                        child: _isLoadingMore
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Muat Lebih Banyak'),
                      ),
                  ],
                ],
              ),
            ),
            const CustomerFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAndControls(
    List<PropertyCategory> categories,
    List<Location> locations,
  ) {
    final int sheetFilterCount = _filter.activeSheetFilterCount;

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Beranda / Katalog Properti',
            style: AppTypography.captionRegular,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text('Katalog Properti', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$_totalCount unit properti tersedia untuk disurvei maupun dipesan.',
            style: AppTypography.bodyNormal,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: _onKeywordChanged,
            onSubmitted: (String value) {
              _debounce?.cancel();
              setState(() => _filter = _filter.copyWith(keyword: value, offset: 0));
              _runSearch(resetPagination: true);
            },
            decoration: InputDecoration(
              hintText: 'Cari tipe, nama cluster, atau alamat...',
              prefixIcon: const Icon(Icons.search, color: AppColors.slate500),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Hapus Kata Kunci',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onKeywordChanged('');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _CategoryFilterChip(
                  label: 'Semua',
                  selected: _filter.categoryId == null,
                  onTap: () {
                    setState(() {
                      _filter = _filter.copyWith(
                        clearCategory: true,
                        offset: 0,
                      );
                    });
                    _runSearch(resetPagination: true);
                  },
                ),
                for (final PropertyCategory cat in categories) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  _CategoryFilterChip(
                    label: cat.name,
                    selected: _filter.categoryId == cat.id,
                    onTap: () {
                      setState(() {
                        _filter = _filter.copyWith(
                          categoryId: cat.id,
                          offset: 0,
                        );
                      });
                      _runSearch(resetPagination: true);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openFilterSheet(locations),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(
                    sheetFilterCount > 0
                        ? 'Filter Daerah ($sheetFilterCount)'
                        : 'Filter Daerah',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Container(
                  height: AppSpacing.buttonHeight,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _filter.sortBy,
                      style: AppTypography.bodyNormal.copyWith(
                        color: AppColors.slate900,
                        fontWeight: FontWeight.w500,
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'newest',
                          child: Text('Terbaru'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'price_asc',
                          child: Text('Harga Termurah'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'price_desc',
                          child: Text('Harga Termahal'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) return;
                        setState(() {
                          _filter = _filter.copyWith(sortBy: value, offset: 0);
                        });
                        _runSearch(resetPagination: true);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterSummary(List<Location> locations) {
    final List<Widget> pills = <Widget>[];
    if (_filter.locationId != null) {
      final Location? match = locations
          .where((Location l) => l.id == _filter.locationId)
          .firstOrNull;
      if (match != null) {
        pills.add(
          Chip(
            label: Text(match.district),
            onDeleted: () {
              setState(() {
                _filter = _filter.copyWith(clearLocation: true, offset: 0);
              });
              _runSearch(resetPagination: true);
            },
          ),
        );
      }
    }
    if (_filter.status != null) {
      pills.add(
        Chip(
          label: Text('Status: ${_filter.status!.label}'),
          onDeleted: () {
            setState(() {
              _filter = _filter.copyWith(clearStatus: true, offset: 0);
            });
            _runSearch(resetPagination: true);
          },
        ),
      );
    }
    if (_filter.minPrice != null || _filter.maxPrice != null) {
      pills.add(
        Chip(
          label: const Text('Filter Harga Aktif'),
          onDeleted: () {
            setState(() {
              _filter = _filter.copyWith(
                clearMinPrice: true,
                clearMaxPrice: true,
                offset: 0,
              );
            });
            _runSearch(resetPagination: true);
          },
        ),
      );
    }

    if (pills.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: pills,
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.emerald500,
      backgroundColor: AppColors.white,
      checkmarkColor: AppColors.white,
      labelStyle: AppTypography.caption.copyWith(
        color: selected ? AppColors.white : AppColors.slate900,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
