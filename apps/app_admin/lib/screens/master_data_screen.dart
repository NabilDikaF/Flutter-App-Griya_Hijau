import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../core/slug_helper.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_scaffold.dart';

/// Layar Master Kategori, Master Daerah, & Akun Admin (`/master-data`)
/// sesuai Tugas 3.2 & Figma `1:3779` (tanpa elemen Paket Full `Pesan WhatsApp otomatis`).
class AdminMasterDataScreen extends ConsumerStatefulWidget {
  const AdminMasterDataScreen({super.key});

  @override
  ConsumerState<AdminMasterDataScreen> createState() =>
      _AdminMasterDataScreenState();
}

class _AdminMasterDataScreenState extends ConsumerState<AdminMasterDataScreen> {
  bool _isLoading = true;
  Object? _error;
  List<PropertyCategory> _categories = const <PropertyCategory>[];
  List<Location> _locations = const <Location>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final AdminRepository repo = ref.read(adminRepositoryProvider);
      final List<PropertyCategory> categories = await repo.getCategories();
      final List<Location> locations = await repo.getLocations();
      if (mounted) {
        setState(() {
          _categories = categories;
          _locations = locations;
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

  Future<void> _openCategoryDialog({PropertyCategory? existing}) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryFormDialog(
        existing: existing,
        repository: ref.read(adminRepositoryProvider),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deleteCategory(PropertyCategory category) async {
    try {
      await ref.read(adminRepositoryProvider).deleteCategory(category.id);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _openLocationDialog({Location? existing}) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (_) => _LocationFormDialog(
        existing: existing,
        repository: ref.read(adminRepositoryProvider),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deleteLocation(Location location) async {
    try {
      await ref.read(adminRepositoryProvider).deleteLocation(location.id);
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
    final AdminSessionUser? user = ref.watch(adminSessionProvider).currentUser;

    return DefaultTabController(
      length: 3,
      child: AdminScaffold(
        currentPath: '/master-data',
        title: 'Master Data & Akun',
        body: Column(
          children: <Widget>[
            Container(
              color: AppColors.white,
              child: const TabBar(
                labelColor: AppColors.emerald800,
                unselectedLabelColor: AppColors.slate500,
                indicatorColor: AppColors.emerald500,
                tabs: <Tab>[
                  Tab(text: 'Kategori'),
                  Tab(text: 'Daerah'),
                  Tab(text: 'Profil & Akun'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const AsyncStateView.loading(
                      message: 'Memuat master data...',
                    )
                  : _error != null
                      ? AsyncStateView.error(
                          message: 'Gagal memuat master data.',
                          onRetry: _load,
                        )
                      : TabBarView(
                          children: <Widget>[
                            _buildCategoriesTab(),
                            _buildLocationsTab(),
                            _buildProfileAndAccountTab(user),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: <Widget>[
        ElevatedButton.icon(
          key: const Key('master_add_category_btn'),
          onPressed: () => _openCategoryDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Kategori Properti'),
        ),
        const SizedBox(height: AppSpacing.md),
        ..._categories.map(
          (PropertyCategory cat) => Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              title: Text(cat.name, style: AppTypography.sectionLabel),
              subtitle: Text(
                '${cat.slug} • ${cat.isActive ? "Aktif" : "Nonaktif"}',
                style: AppTypography.captionRegular,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Ubah kategori',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openCategoryDialog(existing: cat),
                  ),
                  IconButton(
                    tooltip: 'Hapus kategori',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.errorText,
                    ),
                    onPressed: () => _deleteCategory(cat),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationsTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: <Widget>[
        ElevatedButton.icon(
          key: const Key('master_add_location_btn'),
          onPressed: () => _openLocationDialog(),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Tambah Daerah / Kecamatan'),
        ),
        const SizedBox(height: AppSpacing.md),
        ..._locations.map(
          (Location loc) => Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              title: Text(loc.district, style: AppTypography.sectionLabel),
              subtitle: Text(
                '${loc.city} (${loc.slug})',
                style: AppTypography.captionRegular,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Ubah daerah',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openLocationDialog(existing: loc),
                  ),
                  IconButton(
                    tooltip: 'Hapus daerah',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.errorText,
                    ),
                    onPressed: () => _deleteLocation(loc),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAndAccountTab(AdminSessionUser? user) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text('Profil Perusahaan', style: AppTypography.h3),
                SizedBox(height: AppSpacing.md),
                Text(CompanyConfig.displayBrand, style: AppTypography.sectionLabel),
                SizedBox(height: AppSpacing.xs),
                Text(CompanyConfig.officeAddress, style: AppTypography.bodyNormal),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Jam Operasional: ${CompanyConfig.officeHours}',
                  style: AppTypography.captionRegular,
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'WhatsApp Kantor: ${CompanyConfig.officePhoneDisplay}',
                  style: AppTypography.captionRegular,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text('Akun Admin Aktif', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  user?.email ?? '',
                  style: AppTypography.sectionLabel,
                ),
                const SizedBox(height: 2),
                Text(
                  'Peran: ${user?.role ?? "-"}',
                  style: AppTypography.captionRegular,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => ref.read(adminSessionProvider).signOut(),
                  icon: const Icon(Icons.logout, color: AppColors.errorText),
                  label: const Text(
                    'Keluar dari Dashboard Admin',
                    style: TextStyle(color: AppColors.errorText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.existing,
    required this.repository,
  });

  final PropertyCategory? existing;
  final AdminRepository repository;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _slugController = TextEditingController(
    text: widget.existing?.slug ?? '',
  );
  late bool _slugEdited = widget.existing != null;
  late bool _isActive = widget.existing?.isActive ?? true;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final String cleanSlug = SlugHelper.requireValidSlug(_slugController.text);
      if (widget.existing == null) {
        await widget.repository.createCategory(
          name: _nameController.text,
          slug: cleanSlug,
          isActive: _isActive,
        );
      } else {
        await widget.repository.updateCategory(
          id: widget.existing!.id,
          name: _nameController.text,
          slug: cleanSlug,
          isActive: _isActive,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.existing == null ? 'Tambah Kategori' : 'Ubah Kategori',
      ),
      content: SizedBox(
        width: 340,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                key: const Key('master_category_name'),
                controller: _nameController,
                onChanged: (String val) {
                  if (!_slugEdited) {
                    _slugController.text = SlugHelper.slugify(val);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Nama Kategori',
                  hintText: 'Contoh: Tanah Kavling',
                ),
                validator: (String? v) => (v ?? '').trim().isEmpty
                    ? 'Nama kategori wajib diisi'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _slugController,
                onChanged: (_) => _slugEdited = true,
                decoration: const InputDecoration(
                  labelText: 'Slug',
                  hintText: 'tanah-kavling',
                ),
                validator: (String? v) => SlugHelper.validate(v),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif di Katalog'),
                value: _isActive,
                onChanged: (bool val) => setState(() => _isActive = val),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: AppTypography.caption.copyWith(color: AppColors.errorText),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          key: const Key('master_category_save'),
          onPressed: _isSaving ? null : _submit,
          child: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }
}

class _LocationFormDialog extends StatefulWidget {
  const _LocationFormDialog({
    required this.existing,
    required this.repository,
  });

  final Location? existing;
  final AdminRepository repository;

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _cityController = TextEditingController(
    text: widget.existing?.city ?? 'Bandung',
  );
  late final TextEditingController _districtController = TextEditingController(
    text: widget.existing?.district ?? '',
  );
  late final TextEditingController _slugController = TextEditingController(
    text: widget.existing?.slug ?? '',
  );
  late bool _slugEdited = widget.existing != null;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    _districtController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  void _syncSlug() {
    if (_slugEdited) return;
    _slugController.text = SlugHelper.slugify(
      '${_cityController.text} ${_districtController.text}',
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final String cleanSlug = SlugHelper.requireValidSlug(_slugController.text);
      if (widget.existing == null) {
        await widget.repository.createLocation(
          city: _cityController.text,
          district: _districtController.text,
          slug: cleanSlug,
        );
      } else {
        await widget.repository.updateLocation(
          id: widget.existing!.id,
          city: _cityController.text,
          district: _districtController.text,
          slug: cleanSlug,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.existing == null ? 'Tambah Daerah' : 'Ubah Daerah'),
      content: SizedBox(
        width: 340,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                key: const Key('master_location_city'),
                controller: _cityController,
                onChanged: (_) => _syncSlug(),
                decoration: const InputDecoration(
                  labelText: 'Kota / Kabupaten',
                  hintText: 'Bandung',
                ),
                validator: (String? v) =>
                    (v ?? '').trim().isEmpty ? 'Kota wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('master_location_district'),
                controller: _districtController,
                onChanged: (_) => _syncSlug(),
                decoration: const InputDecoration(
                  labelText: 'Kecamatan / Daerah',
                  hintText: 'Kec. Cibiru',
                ),
                validator: (String? v) =>
                    (v ?? '').trim().isEmpty ? 'Kecamatan wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _slugController,
                onChanged: (_) => _slugEdited = true,
                decoration: const InputDecoration(
                  labelText: 'Slug',
                  hintText: 'bandung-kec-cibiru',
                ),
                validator: (String? v) => SlugHelper.validate(v),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: AppTypography.caption.copyWith(color: AppColors.errorText),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          key: const Key('master_location_save'),
          onPressed: _isSaving ? null : _submit,
          child: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }
}
