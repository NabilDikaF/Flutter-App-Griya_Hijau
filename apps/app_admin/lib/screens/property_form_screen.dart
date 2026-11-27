import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../core/slug_helper.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/location_picker_field.dart';

class _StagedLocalPhoto {
  const _StagedLocalPhoto({
    required this.bytes,
    required this.makePrimary,
  });

  final Uint8List bytes;
  final bool makePrimary;

  _StagedLocalPhoto copyWith({bool? makePrimary}) {
    return _StagedLocalPhoto(
      bytes: bytes,
      makePrimary: makePrimary ?? this.makePrimary,
    );
  }
}

/// Layar Form Tambah/Ubah Properti (`/properties/new` & `/properties/:id/edit`)
/// sesuai Figma `1:3725`, `Tugas 3.3` (tanpa input `views_count`), `Tugas 3.4`, & `Tugas 3.5`.
class AdminPropertyFormScreen extends ConsumerStatefulWidget {
  const AdminPropertyFormScreen({super.key, this.propertyId});

  final int? propertyId;

  @override
  ConsumerState<AdminPropertyFormScreen> createState() =>
      _AdminPropertyFormScreenState();
}

class _AdminPropertyFormScreenState
    extends ConsumerState<AdminPropertyFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _buildingAreaController = TextEditingController();
  final TextEditingController _landAreaController = TextEditingController();
  final TextEditingController _bedroomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _floorsController = TextEditingController();
  final TextEditingController _electricityController = TextEditingController();
  final TextEditingController _certificateController = TextEditingController(
    text: 'SHM',
  );
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _mapsUrlController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _slugEditedManually = false;

  List<PropertyCategory> _categories = const <PropertyCategory>[];
  List<Location> _locations = const <Location>[];

  int? _selectedCategoryId;
  int? _selectedLocationId;
  AvailabilityStatus _availabilityStatus = AvailabilityStatus.available;
  bool _isPublished = true;
  int _existingViewsCount = 0;

  List<PropertyImage> _existingImages = <PropertyImage>[];
  final List<_StagedLocalPhoto> _stagedPhotos = <_StagedLocalPhoto>[];

  bool get _isEditMode => widget.propertyId != null;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadInitialData);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _priceController.dispose();
    _buildingAreaController.dispose();
    _landAreaController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _floorsController.dispose();
    _electricityController.dispose();
    _certificateController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _mapsUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final AdminRepository repo = ref.read(adminRepositoryProvider);
      final List<PropertyCategory> categories = await repo.getCategories();
      final List<Location> locations = await repo.getLocations();

      Property? property;
      if (_isEditMode) {
        property = await repo.getPropertyById(widget.propertyId!);
      }

      if (!mounted) return;
      _categories = categories;
      _locations = locations;

      if (property != null) {
        _slugEditedManually = true;
        _titleController.text = property.title;
        _slugController.text = property.slug;
        _priceController.text = property.price.toString();
        _buildingAreaController.text =
            property.buildingArea?.toString() ?? '';
        _landAreaController.text = property.landArea?.toString() ?? '';
        _bedroomsController.text = property.bedrooms?.toString() ?? '';
        _bathroomsController.text = property.bathrooms?.toString() ?? '';
        _floorsController.text = property.floors?.toString() ?? '';
        _electricityController.text = property.electricity ?? '';
        _certificateController.text = property.certificateType ?? '';
        _descriptionController.text = property.description ?? '';
        _addressController.text = property.addressDetail ?? '';
        _latController.text = property.latitude?.toStringAsFixed(6) ?? '';
        _lngController.text = property.longitude?.toStringAsFixed(6) ?? '';
        _mapsUrlController.text = property.googleMapsUrl ?? '';
        _selectedCategoryId = property.propertyCategoryId;
        _selectedLocationId = property.locationId;
        _availabilityStatus = property.availabilityStatus;
        _isPublished = property.isPublished;
        _existingViewsCount = property.viewsCount;
        _existingImages = List<PropertyImage>.from(property.images);
      } else {
        _selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
        _selectedLocationId = locations.isNotEmpty ? locations.first.id : null;
      }
      setState(() => _isLoading = false);
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data form: $error')),
        );
      }
    }
  }

  void _onTitleChanged(String value) {
    if (_slugEditedManually) return;
    _slugController.text = SlugHelper.slugify(value);
  }

  Future<void> _pickAndUploadPhoto() async {
    final int currentCount = _existingImages.length + _stagedPhotos.length;
    if (currentCount >= CompanyConfig.maxImagesPerProperty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maksimal ${CompanyConfig.maxImagesPerProperty} foto per properti.',
          ),
        ),
      );
      return;
    }

    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final Uint8List rawBytes = await picked.readAsBytes();

    if (!_isEditMode) {
      setState(() {
        _stagedPhotos.add(
          _StagedLocalPhoto(
            bytes: rawBytes,
            makePrimary: _stagedPhotos.isEmpty,
          ),
        );
      });
      return;
    }

    setState(() => _isUploadingPhoto = true);
    try {
      final AdminRepository repo = ref.read(adminRepositoryProvider);
      await repo.uploadPropertyPhoto(
        propertyId: widget.propertyId!,
        rawBytes: rawBytes,
        makePrimary: _existingImages.isEmpty,
        sortOrder: _existingImages.length,
      );
      final Property? refreshed = await repo.getPropertyById(widget.propertyId!);
      if (mounted && refreshed != null) {
        setState(() {
          _existingImages = List<PropertyImage>.from(refreshed.images);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto berhasil dikompres & diunggah.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah foto: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _setPrimaryExistingPhoto(PropertyImage image) async {
    if (widget.propertyId == null) return;
    final AdminRepository repo = ref.read(adminRepositoryProvider);
    await repo.setPrimaryPhoto(widget.propertyId!, image.id);
    final Property? refreshed = await repo.getPropertyById(widget.propertyId!);
    if (mounted && refreshed != null) {
      setState(() {
        _existingImages = List<PropertyImage>.from(refreshed.images);
      });
    }
  }

  Future<void> _moveExistingPhoto(int oldIndex, int delta) async {
    final int newIndex = oldIndex + delta;
    if (newIndex < 0 || newIndex >= _existingImages.length) return;
    if (widget.propertyId == null) return;
    final List<PropertyImage> reordered =
        List<PropertyImage>.from(_existingImages);
    final PropertyImage item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    await ref
        .read(adminRepositoryProvider)
        .reorderPropertyPhotos(widget.propertyId!, reordered);
    final Property? refreshed =
        await ref.read(adminRepositoryProvider).getPropertyById(widget.propertyId!);
    if (mounted && refreshed != null) {
      setState(() {
        _existingImages = List<PropertyImage>.from(refreshed.images);
      });
    }
  }

  Future<void> _deleteExistingPhoto(PropertyImage image) async {
    final AdminRepository repo = ref.read(adminRepositoryProvider);
    await repo.deletePropertyPhoto(image);
    final Property? refreshed = widget.propertyId != null
        ? await repo.getPropertyById(widget.propertyId!)
        : null;
    if (mounted) {
      setState(() {
        if (refreshed != null) {
          _existingImages = List<PropertyImage>.from(refreshed.images);
        } else {
          _existingImages.removeWhere((PropertyImage i) => i.id == image.id);
        }
      });
    }
  }

  int? _parseOptionalInt(TextEditingController c) {
    final String trimmed = c.text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  String? _trimOrNull(TextEditingController c) {
    final String trimmed = c.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _saveProperty() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategoryId == null || _selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori dan daerah properti.')),
      );
      return;
    }

    final int price = int.parse(
      _priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final String rawSlug = _slugController.text.trim();
    final String finalSlug = SlugHelper.requireValidSlug(
      rawSlug.isEmpty ? _titleController.text : rawSlug,
      fieldLabel: 'Slug properti',
    );

    double? lat = double.tryParse(_latController.text.trim());
    double? lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      final (double, double)? parsedUrlCoords =
          LocationPickerField.tryParseLatLngFromUrl(_mapsUrlController.text);
      if (parsedUrlCoords != null) {
        lat = parsedUrlCoords.$1;
        lng = parsedUrlCoords.$2;
      }
    }

    // Seluruh data memakai `PropertyInput` tanpa field `views_count`.
    final PropertyInput input = PropertyInput(
      propertyCategoryId: _selectedCategoryId!,
      locationId: _selectedLocationId!,
      title: _titleController.text.trim(),
      slug: finalSlug,
      price: price,
      buildingArea: _parseOptionalInt(_buildingAreaController),
      landArea: _parseOptionalInt(_landAreaController),
      bedrooms: _parseOptionalInt(_bedroomsController),
      bathrooms: _parseOptionalInt(_bathroomsController),
      floors: _parseOptionalInt(_floorsController),
      electricity: _trimOrNull(_electricityController),
      certificateType: _trimOrNull(_certificateController),
      description: _trimOrNull(_descriptionController),
      addressDetail: _trimOrNull(_addressController),
      latitude: lat,
      longitude: lng,
      googleMapsUrl: _trimOrNull(_mapsUrlController),
      availabilityStatus: _availabilityStatus,
      isPublished: _isPublished,
    );

    setState(() => _isSaving = true);
    try {
      final AdminRepository repo = ref.read(adminRepositoryProvider);
      if (_isEditMode) {
        await repo.updateProperty(widget.propertyId!, input);
      } else {
        final Property created = await repo.createProperty(input);
        for (int i = 0; i < _stagedPhotos.length; i++) {
          await repo.uploadPropertyPhoto(
            propertyId: created.id,
            rawBytes: _stagedPhotos[i].bytes,
            makePrimary: _stagedPhotos[i].makePrimary,
            sortOrder: i,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Perubahan properti berhasil disimpan.'
                : 'Properti baru berhasil ditambahkan.',
          ),
        ),
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/properties');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      currentPath: '/properties',
      title: _isEditMode ? 'Ubah Properti' : 'Tambah Properti',
      showBackButton: true,
      showBottomNav: false,
      body: _isLoading
          ? const AsyncStateView.loading(
              message: 'Menyiapkan formulir properti...',
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                children: <Widget>[
                  _buildBasicInfoSection(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSpecsSection(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDescriptionAndLocationSection(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildPhotosSection(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildReadOnlyViewsCard(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildPublishSection(),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton.icon(
                    key: const Key('admin_property_save'),
                    onPressed: _isSaving ? null : _saveProperty,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Properti',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Informasi Dasar', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('property_title_input'),
              controller: _titleController,
              onChanged: _onTitleChanged,
              decoration: const InputDecoration(
                labelText: 'Nama / Judul Properti *',
                hintText: 'Contoh: Griya Hijau Residence Tipe 45/84',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? 'Judul properti wajib diisi' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _slugController,
              onChanged: (_) => _slugEditedManually = true,
              decoration: const InputDecoration(
                labelText: 'Slug URL *',
                hintText: 'griya-hijau-residence-45-84',
              ),
              validator: (String? v) =>
                  SlugHelper.validate(v, fieldLabel: 'Slug properti'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<int>(
              key: const Key('admin_property_category_dropdown'),
              label: 'Kategori *',
              hint: 'Pilih kategori',
              value: _selectedCategoryId,
              items: _categories
                  .map(
                    (PropertyCategory c) => AppDropdownItem<int>(
                      value: c.id,
                      label: c.isActive ? c.name : '${c.name} (Nonaktif)',
                    ),
                  )
                  .toList(growable: false),
              onChanged: (int? v) => setState(() => _selectedCategoryId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<int>(
              key: const Key('admin_property_location_dropdown'),
              label: 'Daerah / Kecamatan *',
              hint: 'Pilih daerah / kecamatan',
              value: _selectedLocationId,
              items: _locations
                  .map(
                    (Location l) => AppDropdownItem<int>(
                      value: l.id,
                      label: l.displayName,
                    ),
                  )
                  .toList(growable: false),
              onChanged: (int? v) => setState(() => _selectedLocationId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('property_price_input'),
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga (Rp) *',
                hintText: '680000000',
                prefixText: 'Rp ',
              ),
              validator: (String? v) {
                final String digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                final int? parsed = int.tryParse(digits);
                if (parsed == null || parsed <= 0) {
                  return 'Masukkan harga properti yang valid';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Status Ketersediaan', style: AppTypography.sectionLabel),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: AvailabilityStatus.values.map((AvailabilityStatus s) {
                return ChoiceChip(
                  label: Text(s.label),
                  selected: _availabilityStatus == s,
                  onSelected: (_) => setState(() => _availabilityStatus = s),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Spesifikasi Unit', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _buildingAreaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Luas Bangunan (m²)'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _landAreaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Luas Tanah (m²)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _bedroomsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kamar Tidur'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _bathroomsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kamar Mandi'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _floorsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Jumlah Lantai'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _electricityController,
                    decoration: const InputDecoration(
                      labelText: 'Daya Listrik',
                      hintText: '1300 VA',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _certificateController,
              decoration: const InputDecoration(
                labelText: 'Sertifikat Legalitas',
                hintText: 'SHM / HGB',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionAndLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Deskripsi & Lokasi', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Properti',
                hintText: 'Jelaskan keunggulan lokasi, fasilitas kawasan, dan spesifikasi.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alamat Lengkap',
                hintText: 'Jl. Rindang Raya Blok A1 No. 5, Kec. Sukamaju',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            LocationPickerField(
              latitudeController: _latController,
              longitudeController: _lngController,
              googleMapsUrlController: _mapsUrlController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    final AdminRepository repo = ref.read(adminRepositoryProvider);
    final int totalPhotos = _existingImages.length + _stagedPhotos.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('Foto Properti', style: AppTypography.h2),
                ),
                Text(
                  '$totalPhotos / ${CompanyConfig.maxImagesPerProperty}',
                  style: AppTypography.caption,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Foto otomatis dikompresi maks lebar 1600px dan < 1 MB sebelum diunggah.',
              style: AppTypography.captionRegular,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
              icon: _isUploadingPhoto
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _isUploadingPhoto ? 'Mengunggah foto...' : 'Unggah Foto Properti',
              ),
            ),
            if (_isEditMode && _existingImages.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              ..._existingImages.asMap().entries.map((MapEntry<int, PropertyImage> e) {
                final int idx = e.key;
                final PropertyImage img = e.value;
                final Uint8List? localBytes =
                    repo.getLocalImageBytes(img.imagePath);
                final String? url = repo.resolveImageUrl(img.imagePath);
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: img.isPrimary
                          ? AppColors.emerald500
                          : AppColors.slate200,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        child: SizedBox(
                          width: 56,
                          height: 44,
                          child: localBytes != null
                              ? Image.memory(localBytes, fit: BoxFit.cover)
                              : url != null
                                  ? Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.image_outlined,
                                        color: AppColors.slate500,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image_outlined,
                                      color: AppColors.slate500,
                                    ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              img.isPrimary ? 'Foto Utama' : 'Foto #${idx + 1}',
                              style: AppTypography.sectionLabel,
                            ),
                            Text(
                              img.imagePath,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.captionRegular,
                            ),
                          ],
                        ),
                      ),
                      if (!img.isPrimary)
                        IconButton(
                          tooltip: 'Jadikan Foto Utama',
                          icon: const Icon(Icons.star_border),
                          onPressed: () => _setPrimaryExistingPhoto(img),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.star,
                            color: AppColors.emerald500,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Naikkan urutan',
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed:
                            idx > 0 ? () => _moveExistingPhoto(idx, -1) : null,
                      ),
                      IconButton(
                        tooltip: 'Turunkan urutan',
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: idx < _existingImages.length - 1
                            ? () => _moveExistingPhoto(idx, 1)
                            : null,
                      ),
                      IconButton(
                        tooltip: 'Hapus foto',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.errorText,
                        ),
                        onPressed: () => _deleteExistingPhoto(img),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (!_isEditMode && _stagedPhotos.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              ..._stagedPhotos.asMap().entries.map((MapEntry<int, _StagedLocalPhoto> e) {
                final int idx = e.key;
                final _StagedLocalPhoto photo = e.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Image.memory(
                    photo.bytes,
                    width: 56,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                  title: Text(photo.makePrimary ? 'Foto Utama' : 'Foto #${idx + 1}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Jadikan Utama',
                        icon: Icon(
                          photo.makePrimary ? Icons.star : Icons.star_border,
                          color: photo.makePrimary
                              ? AppColors.emerald500
                              : AppColors.slate500,
                        ),
                        onPressed: () {
                          setState(() {
                            for (int i = 0; i < _stagedPhotos.length; i++) {
                              _stagedPhotos[i] = _stagedPhotos[i].copyWith(
                                makePrimary: i == idx,
                              );
                            }
                          });
                        },
                      ),
                      IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.errorText,
                        ),
                        onPressed: () {
                          setState(() {
                            _stagedPhotos.removeAt(idx);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// Kartu statistik `views_count` read-only sesuai Figma `1:3710`.
  /// Tidak memiliki TextFormField atau kontrol ubah apa pun.
  Widget _buildReadOnlyViewsCard() {
    return Card(
      key: const Key('property_readonly_views_card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: const <Widget>[
                Expanded(
                  child: Text('Jumlah Dilihat (Otomatis)', style: AppTypography.h2),
                ),
                Icon(Icons.lock_outline, size: 18, color: AppColors.slate500),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ViewsLockBadge(viewsCount: _existingViewsCount),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Angka dihitung otomatis oleh sistem dari kunjungan halaman detail pelanggan dan dilindungi agar tidak dapat diubah manual.',
              style: AppTypography.captionRegular,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Status Publikasi', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Dipublikasikan di Katalog'),
                  selected: _isPublished,
                  onSelected: (_) => setState(() => _isPublished = true),
                ),
                ChoiceChip(
                  label: const Text('Simpan sebagai Draft'),
                  selected: !_isPublished,
                  onSelected: (_) => setState(() => _isPublished = false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
