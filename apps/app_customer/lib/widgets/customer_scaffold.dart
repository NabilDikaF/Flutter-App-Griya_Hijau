import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../core/external_launcher.dart';

/// Kerangka navigasi utama Customer App sesuai `Navbar/Mobile`, `Menu Mobile`, & `Footer/Mobile`.
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
            : Builder(
                builder: (BuildContext scaffoldContext) => IconButton(
                  tooltip: 'Menu Navigasi',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                ),
              ),
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
      drawer: _CustomerNavigationDrawer(currentPath: currentPath),
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

class _CustomerNavigationDrawer extends StatelessWidget {
  const _CustomerNavigationDrawer({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.emerald500,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.home_work_outlined,
                      color: AppColors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const <Widget>[
                        Text(
                          CompanyConfig.brandName,
                          style: AppTypography.h3,
                        ),
                        Text(
                          CompanyConfig.companyName,
                          style: AppTypography.captionRegular,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            _DrawerItem(
              icon: Icons.home_outlined,
              label: 'Beranda',
              selected: currentPath == '/',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/');
              },
            ),
            _DrawerItem(
              icon: Icons.apartment_outlined,
              label: 'Katalog Properti',
              selected: currentPath == '/katalog',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/katalog');
              },
            ),
            _DrawerItem(
              icon: Icons.fact_check_outlined,
              label: 'Cek Booking',
              selected: currentPath == '/cek-booking',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/cek-booking');
              },
            ),
            _DrawerItem(
              icon: Icons.info_outline,
              label: 'Tentang Kami',
              selected: currentPath == '/tentang-kami',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/tentang-kami');
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/katalog');
                    },
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Lihat Katalog Properti'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ExternalLauncher.openWhatsapp(
                        context,
                        prefilledMessage:
                            'Halo admin ${CompanyConfig.brandName}, saya ingin bertanya mengenai unit properti yang tersedia.',
                      );
                    },
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Hubungi via WhatsApp'),
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

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? AppColors.emerald800 : AppColors.slate500,
      ),
      title: Text(
        label,
        style: AppTypography.bodyMedium15.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.emerald800 : AppColors.slate900,
        ),
      ),
      selected: selected,
      selectedTileColor: AppColors.emerald50,
      onTap: onTap,
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
