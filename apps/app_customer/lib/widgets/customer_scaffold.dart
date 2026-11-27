import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

/// Kerangka navigasi utama Customer App sesuai `Navbar/Mobile` & `Footer/Mobile`.
/// Tidak menyertakan tombol atau fitur AI sesuai cakupan Paket Semi Full.
class CustomerScaffold extends StatelessWidget {
  const CustomerScaffold({
    super.key,
    required this.currentPath,
    required this.body,
    this.title,
    this.showBackButton = false,
    this.showBottomNav = true,
    this.bottomNavigationBar,
  });

  final String currentPath;
  final Widget body;
  final String? title;
  final bool showBackButton;
  final bool showBottomNav;
  final Widget? bottomNavigationBar;

  int get _selectedIndex {
    if (currentPath.startsWith('/katalog')) return 1;
    if (currentPath.startsWith('/cek-booking')) return 2;
    if (currentPath.startsWith('/tentang-kami')) return 3;
    return 0;
  }

  void _navigateTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/katalog');
        break;
      case 2:
        context.go('/cek-booking');
        break;
      case 3:
        context.go('/tentang-kami');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.pagePadding,
        leading: showBackButton
            ? IconButton(
                tooltip: 'Kembali',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              )
            : null,
        title: title != null
            ? Text(title!)
            : Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.emerald500,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Icon(
                      Icons.home_work_outlined,
                      color: AppColors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          CompanyConfig.brandName,
                          style: AppTypography.sectionLabel.copyWith(
                            fontSize: 15,
                          ),
                        ),
                        const Text(
                          CompanyConfig.companyName,
                          style: AppTypography.captionRegular,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      body: body,
      bottomNavigationBar: bottomNavigationBar ??
          (showBottomNav && !showBackButton && currentPath != '/booking-berhasil'
              ? NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) =>
                      _navigateTab(context, index),
                  backgroundColor: AppColors.white,
                  indicatorColor: AppColors.emerald100,
                  destinations: const <NavigationDestination>[
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(
                        Icons.home,
                        color: AppColors.emerald800,
                      ),
                      label: 'Beranda',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.apartment_outlined),
                      selectedIcon: Icon(
                        Icons.apartment,
                        color: AppColors.emerald800,
                      ),
                      label: 'Katalog',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.fact_check_outlined),
                      selectedIcon: Icon(
                        Icons.fact_check,
                        color: AppColors.emerald800,
                      ),
                      label: 'Cek Booking',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.info_outline),
                      selectedIcon: Icon(
                        Icons.info,
                        color: AppColors.emerald800,
                      ),
                      label: 'Tentang Kami',
                    ),
                  ],
                )
              : null),
    );
  }
}

/// Footer informasi perusahaan sesuai komponen Figma `Footer/Mobile`.
class CustomerFooter extends StatelessWidget {
  const CustomerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate900,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            CompanyConfig.displayBrand,
            style: AppTypography.h3.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            CompanyConfig.shortDescription,
            style: AppTypography.bodyNormal.copyWith(
              color: AppColors.slate200,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _FooterLink(label: 'Beranda', onTap: () => context.go('/')),
              _FooterLink(
                label: 'Katalog Properti',
                onTap: () => context.go('/katalog'),
              ),
              _FooterLink(
                label: 'Cek Booking',
                onTap: () => context.go('/cek-booking'),
              ),
              _FooterLink(
                label: 'Tentang Kami',
                onTap: () => context.go('/tentang-kami'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Divider(color: AppColors.slate600),
          ),
          Text(
            'Kantor Pemasaran',
            style: AppTypography.sectionLabel.copyWith(
              color: AppColors.emerald200,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CompanyConfig.officeAddress,
            style: AppTypography.captionRegular.copyWith(
              color: AppColors.slate200,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${CompanyConfig.officeHours} • WA: ${CompanyConfig.officePhoneDisplay}',
            style: AppTypography.captionRegular.copyWith(
              color: AppColors.slate200,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '© 2026 ${CompanyConfig.companyName}. Semua hak dilindungi.',
            style: AppTypography.captionRegular.copyWith(
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          label,
          style: AppTypography.bodyNormal.copyWith(
            color: AppColors.emerald200,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
