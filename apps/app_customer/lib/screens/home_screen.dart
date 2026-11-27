import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../core/external_launcher.dart';
import '../data/customer_repository.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/customer_scaffold.dart';

/// Layar Beranda (`/`) sesuai Figma `Beranda - Mobile` & Tugas 2.1.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _keywordController = TextEditingController();
  int? _selectedCategoryId;
  int? _selectedLocationId;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final Map<String, String> query = <String, String>{};
    final String trimmed = _keywordController.text.trim();
    if (trimmed.isNotEmpty) {
      query['q'] = trimmed;
    }
    if (_selectedCategoryId != null) {
      query['categoryId'] = _selectedCategoryId.toString();
    }
    if (_selectedLocationId != null) {
      query['locationId'] = _selectedLocationId.toString();
    }
    context.go(Uri(path: '/katalog', queryParameters: query.isEmpty ? null : query).toString());
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CustomerBootstrapData> bootstrapAsync =
        ref.watch(customerBootstrapProvider);
    final CustomerRepository repository = ref.watch(customerRepositoryProvider);

    return CustomerScaffold(
      currentPath: '/',
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(customerBootstrapProvider.future),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _buildHeroAndSearch(
              bootstrapAsync.asData?.value,
              useLocalFallback: repository.isUsingLocalSeeder,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.xl,
                AppSpacing.pagePadding,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text('Proyek Unggulan', style: AppTypography.h2),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Pilih unit rumah atau ruko yang sesuai dengan kebutuhan keluarga maupun usaha Anda.',
                    style: AppTypography.bodyNormal,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  bootstrapAsync.when(
                    loading: () => const AsyncStateView.loading(),
                    error: (Object error, StackTrace stackTrace) =>
                        AsyncStateView.error(
                      onRetry: () => ref.invalidate(customerBootstrapProvider),
                    ),
                    data: (CustomerBootstrapData data) {
                      if (data.featuredProperties.isEmpty) {
                        return AsyncStateView.empty(
                          title: 'Belum ada properti unggulan',
                          message:
                              'Unit properti terpublikasi akan tampil di sini.',
                          onRetry: () =>
                              ref.invalidate(customerBootstrapProvider),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final PropertySummary item
                              in data.featuredProperties) ...<Widget>[
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
                          OutlinedButton.icon(
                            onPressed: () => context.go('/katalog'),
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('Lihat Semua Properti'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const _CompanyHighlightsSection(),
            const _MarketingOfficeCardSection(),
            const CustomerFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroAndSearch(
    CustomerBootstrapData? data, {
    required bool useLocalFallback,
  }) {
    final List<PropertyCategory> categories = data?.categories ??
        (useLocalFallback
            ? SeedData.categories
            : const <PropertyCategory>[]);
    final List<Location> locations = data?.locations ??
        (useLocalFallback ? SeedData.locations : const <Location>[]);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.emerald950, AppColors.emerald800],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.xl,
        AppSpacing.pagePadding,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.emerald500.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border: Border.all(
                  color: AppColors.emerald200.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'Developer Properti Terpercaya',
                style: AppTypography.caption.copyWith(
                  color: AppColors.emerald100,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Temukan rumah dan ruko impian Anda',
            style: AppTypography.h2.copyWith(
              color: AppColors.white,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            CompanyConfig.tagline,
            style: AppTypography.bodyMedium15.copyWith(
              color: AppColors.emerald100,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    controller: _keywordController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submitSearch(),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama perumahan, ruko, atau alamat...',
                      prefixIcon: Icon(Icons.search, color: AppColors.slate500),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Kategori', style: AppTypography.inputLabel),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      _CategoryChoiceChip(
                        label: 'Semua',
                        selected: _selectedCategoryId == null,
                        onSelected: () =>
                            setState(() => _selectedCategoryId = null),
                      ),
                      for (final PropertyCategory cat in categories)
                        _CategoryChoiceChip(
                          label: cat.name,
                          selected: _selectedCategoryId == cat.id,
                          onSelected: () =>
                              setState(() => _selectedCategoryId = cat.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppDropdown<int?>(
                    key: const Key('home_location_dropdown'),
                    label: 'Daerah',
                    hint: 'Semua daerah',
                    value: locations.any(
                      (Location l) => l.id == _selectedLocationId,
                    )
                        ? _selectedLocationId
                        : null,
                    items: <AppDropdownItem<int?>>[
                      const AppDropdownItem<int?>(
                        value: null,
                        label: 'Semua daerah',
                      ),
                      for (final Location loc in locations)
                        AppDropdownItem<int?>(
                          value: loc.id,
                          label: loc.displayName,
                        ),
                    ],
                    onChanged: (int? value) {
                      setState(() => _selectedLocationId = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: _submitSearch,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Cari Properti'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChoiceChip extends StatelessWidget {
  const _CategoryChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      labelStyle: AppTypography.caption.copyWith(
        color: selected ? AppColors.white : AppColors.slate900,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: AppColors.emerald500,
      backgroundColor: AppColors.white,
      checkmarkColor: AppColors.white,
      onSelected: (_) => onSelected(),
    );
  }
}

class _CompanyHighlightsSection extends StatelessWidget {
  const _CompanyHighlightsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Mengapa Memilih ${CompanyConfig.brandName}',
            style: AppTypography.h2,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Komitmen kami menghadirkan hunian nyaman dan legalitas yang aman.',
            style: AppTypography.bodyNormal,
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: CompanyConfig.stats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (BuildContext context, int index) {
              final CompanyStat stat = CompanyConfig.stats[index];
              return Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.emerald200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      stat.value,
                      style: AppTypography.h2.copyWith(
                        color: AppColors.emerald800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      stat.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.emerald950,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MarketingOfficeCardSection extends StatelessWidget {
  const _MarketingOfficeCardSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Kantor Pemasaran', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.md),
              _InfoLine(
                icon: Icons.location_on_outlined,
                text: CompanyConfig.officeAddress,
              ),
              const SizedBox(height: AppSpacing.sm),
              const _InfoLine(
                icon: Icons.schedule_outlined,
                text: CompanyConfig.officeHours,
              ),
              const SizedBox(height: AppSpacing.sm),
              const _InfoLine(
                icon: Icons.phone_outlined,
                text: 'WhatsApp: ${CompanyConfig.officePhoneDisplay}',
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () => ExternalLauncher.openWhatsapp(
                  context,
                  prefilledMessage:
                      'Halo tim pemasaran ${CompanyConfig.brandName}, saya ingin berkonsultasi mengenai unit properti.',
                ),
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Konsultasi via WhatsApp'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => context.go('/tentang-kami'),
                child: const Text('Profil Lengkap Perusahaan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: AppColors.emerald600),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTypography.bodyNormal)),
      ],
    );
  }
}
