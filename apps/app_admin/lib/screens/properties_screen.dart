import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_scaffold.dart';

/// Layar daftar & manajemen properti (`/properties`) sesuai Figma `1:3560` & Tugas 3.3.
class AdminPropertiesScreen extends ConsumerStatefulWidget {
  const AdminPropertiesScreen({super.key});

  @override
  ConsumerState<AdminPropertiesScreen> createState() =>
      _AdminPropertiesScreenState();
}

class _AdminPropertiesScreenState extends ConsumerState<AdminPropertiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  Object? _error;
  List<Property> _properties = const <Property>[];
  List<PropertyCategory> _categories = const <PropertyCategory>[];

  int? _selectedCategoryId;
  bool _onlyDrafts = false;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final AdminRepository repo = ref.read(adminRepositoryProvider);
      final List<PropertyCategory> categories = await repo.getCategories();
      final List<Property> properties = await repo.getAdminProperties();
      if (mounted) {
        setState(() {
          _categories = categories;
          _properties = properties;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      }
    }
  }

  List<Property> get _filteredProperties {
    final String lower = _keyword.trim().toLowerCase();
    return _properties.where((Property item) {
      if (_onlyDrafts && item.isPublished) return false;
      if (!_onlyDrafts &&
          _selectedCategoryId != null &&
          item.propertyCategoryId != _selectedCategoryId) {
        return false;
      }
      if (lower.isNotEmpty) {
        final bool matchTitle = item.title.toLowerCase().contains(lower);
        final bool matchDistrict =
            (item.location?.district ?? '').toLowerCase().contains(lower);
        final bool matchAddress =
            (item.addressDetail ?? '').toLowerCase().contains(lower);
        return matchTitle || matchDistrict || matchAddress;
      }
      return true;
    }).toList(growable: false);
  }

  Future<void> _handleDeleteOrHide(Property property) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus atau Nonaktifkan Properti'),
        content: Text(
          'Hapus "${property.title}"? Jika properti sudah memiliki riwayat booking, '
          'sistem otomatis menyembunyikannya (Draft) alih-alih menghapus permanen.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorText,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final PropertyDeleteResult result = await ref
          .read(adminRepositoryProvider)
          .deleteOrDeactivateProperty(property.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Property> visible = _filteredProperties;
    final AdminRepository repo = ref.read(adminRepositoryProvider);

    return AdminScaffold(
      currentPath: '/properties',
      title: 'Kelola Properti',
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('admin_add_property_fab'),
        onPressed: () async {
          final Object? changed = await context.push('/properties/new');
          if (changed == true || mounted) {
            await _load();
          }
        },
        backgroundColor: AppColors.emerald500,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Properti'),
      ),
      body: _isLoading && _properties.isEmpty
          ? const AsyncStateView.loading(message: 'Memuat daftar properti...')
          : _error != null && _properties.isEmpty
              ? AsyncStateView.error(
                  message: 'Gagal memuat daftar properti.',
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.pagePadding,
                      AppSpacing.pagePadding,
                      96,
                    ),
                    children: <Widget>[
                      TextField(
                        controller: _searchController,
                        onChanged: (String value) {
                          setState(() => _keyword = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari nama properti atau kecamatan...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _keyword.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _keyword = '');
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
                            FilterChip(
                              label: Text('Semua (${_properties.length})'),
                              selected: !_onlyDrafts && _selectedCategoryId == null,
                              onSelected: (_) => setState(() {
                                _onlyDrafts = false;
                                _selectedCategoryId = null;
                              }),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            ..._categories.map((PropertyCategory cat) {
                              return Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.xs),
                                child: FilterChip(
                                  label: Text(cat.name),
                                  selected: !_onlyDrafts &&
                                      _selectedCategoryId == cat.id,
                                  onSelected: (_) => setState(() {
                                    _onlyDrafts = false;
                                    _selectedCategoryId = cat.id;
                                  }),
                                ),
                              );
                            }),
                            FilterChip(
                              label: Text(
                                'Draft (${_properties.where((Property p) => !p.isPublished).length})',
                              ),
                              selected: _onlyDrafts,
                              onSelected: (_) => setState(() {
                                _onlyDrafts = !_onlyDrafts;
                                if (_onlyDrafts) _selectedCategoryId = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const ReadOnlyViewsBanner(),
                      const SizedBox(height: AppSpacing.md),
                      if (visible.isEmpty)
                        const AsyncStateView.empty(
                          icon: Icons.apartment_outlined,
                          title: 'Tidak ada properti yang cocok',
                          message:
                              'Ubah kata kunci atau tambahkan unit properti baru.',
                        )
                      else
                        ...visible.map((Property item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _AdminPropertyCard(
                              property: item,
                              imageUrl: repo.resolveImageUrl(
                                item.primaryImagePath,
                              ),
                              localBytes: item.primaryImagePath != null
                                  ? repo.getLocalImageBytes(item.primaryImagePath!)
                                  : null,
                              onEdit: () async {
                                await context.push('/properties/${item.id}/edit');
                                await _load();
                              },
                              onChangeAvailability: (AvailabilityStatus next) async {
                                await repo.updatePropertyAvailability(
                                  item.id,
                                  next,
                                );
                                await _load();
                              },
                              onTogglePublished: () async {
                                await repo.updatePropertyPublished(
                                  item.id,
                                  !item.isPublished,
                                );
                                await _load();
                              },
                              onDeleteOrHide: () => _handleDeleteOrHide(item),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _AdminPropertyCard extends StatelessWidget {
  const _AdminPropertyCard({
    required this.property,
    required this.imageUrl,
    required this.localBytes,
    required this.onEdit,
    required this.onChangeAvailability,
    required this.onTogglePublished,
    required this.onDeleteOrHide,
  });

  final Property property;
  final String? imageUrl;
  final Uint8List? localBytes;
  final VoidCallback onEdit;
  final ValueChanged<AvailabilityStatus> onChangeAvailability;
  final VoidCallback onTogglePublished;
  final VoidCallback onDeleteOrHide;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PropertyThumbnail(
                  imageUrl: imageUrl,
                  localBytes: localBytes,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        property.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.sectionLabel,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        property.location?.district ?? '-',
                        style: AppTypography.captionRegular,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          AvailabilityBadge(status: property.availabilityStatus),
                          if (!property.isPublished)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.slate200,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusPill,
                                ),
                              ),
                              child: Text(
                                'Draft',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.slate900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        property.category?.name ?? 'Properti',
                        style: AppTypography.captionRegular,
                      ),
                      Text(
                        AppFormatters.rupiah(property.price),
                        style: AppTypography.h3.copyWith(
                          fontSize: 16,
                          color: AppColors.emerald800,
                        ),
                      ),
                    ],
                  ),
                ),
                ViewsLockBadge(viewsCount: property.viewsCount),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Ubah'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PopupMenuButton<String>(
                  tooltip: 'Aksi lainnya',
                  onSelected: (String value) {
                    switch (value) {
                      case 'status_available':
                        onChangeAvailability(AvailabilityStatus.available);
                        break;
                      case 'status_booked':
                        onChangeAvailability(AvailabilityStatus.booked);
                        break;
                      case 'status_sold':
                        onChangeAvailability(AvailabilityStatus.sold);
                        break;
                      case 'toggle_publish':
                        onTogglePublished();
                        break;
                      case 'delete':
                        onDeleteOrHide();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'status_available',
                      child: Text('Tandai: Tersedia'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'status_booked',
                      child: Text('Tandai: Dipesan'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'status_sold',
                      child: Text('Tandai: Terjual'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'toggle_publish',
                      child: Text(
                        property.isPublished
                            ? 'Sembunyikan ke Draft'
                            : 'Publikasikan di Katalog',
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        'Hapus / Nonaktifkan',
                        style: TextStyle(color: AppColors.errorText),
                      ),
                    ),
                  ],
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.slate200),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.more_horiz, color: AppColors.slate600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyThumbnail extends StatelessWidget {
  const _PropertyThumbnail({
    required this.imageUrl,
    required this.localBytes,
  });

  final String? imageUrl;
  final Uint8List? localBytes;

  @override
  Widget build(BuildContext context) {
    Widget child = const Icon(
      Icons.apartment_outlined,
      color: AppColors.slate500,
    );

    if (localBytes != null) {
      child = Image.memory(localBytes!, fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(
          Icons.apartment_outlined,
          color: AppColors.slate500,
        ),
      );
    }

    return Container(
      width: 72,
      height: 54,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: child,
    );
  }
}
