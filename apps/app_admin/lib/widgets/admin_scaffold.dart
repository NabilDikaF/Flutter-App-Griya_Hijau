import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../data/admin_models.dart';
import '../data/admin_repository.dart';

/// Kerangka navigasi utama Aplikasi Admin sesuai Figma `1:2802 Menu Admin - Mobile`
/// & `Navigasi Bawah Admin`.
class AdminScaffold extends ConsumerWidget {
  const AdminScaffold({
    super.key,
    required this.currentPath,
    required this.title,
    required this.body,
    this.showBackButton = false,
    this.showBottomNav = true,
    this.floatingActionButton,
    this.actions,
  });

  final String currentPath;
  final String title;
  final Widget body;
  final bool showBackButton;
  final bool showBottomNav;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  int get _selectedIndex {
    if (currentPath.startsWith('/properties')) return 1;
    if (currentPath.startsWith('/bookings')) return 2;
    if (currentPath.startsWith('/master-data')) return 3;
    return 0;
  }

  void _navigateTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/properties');
        break;
      case 2:
        context.go('/bookings');
        break;
      case 3:
        context.go('/master-data');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AdminSessionNotifier session = ref.watch(adminSessionProvider);
    final AdminSessionUser? user = session.currentUser;

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
                    context.go('/dashboard');
                  }
                },
              )
            : Builder(
                builder: (BuildContext scaffoldContext) => IconButton(
                  tooltip: 'Menu Admin',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                ),
              ),
        title: Text(title),
        actions: <Widget>[
          ...?actions,
          PopupMenuButton<String>(
            tooltip: 'Akun Admin',
            onSelected: (String value) async {
              if (value == 'logout') {
                await ref.read(adminSessionProvider).signOut();
              } else if (value == 'master') {
                context.go('/master-data');
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('Admin Terautentikasi', style: AppTypography.caption),
                    Text(
                      user?.email ?? '',
                      style: AppTypography.bodyNormal,
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'master',
                child: Text('Master Data & Akun'),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text(
                  'Keluar',
                  style: TextStyle(color: AppColors.errorText),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.emerald100,
                child: Text(
                  user?.avatarInitial ?? 'A',
                  style: AppTypography.sectionLabel.copyWith(
                    color: AppColors.emerald800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: showBackButton
          ? null
          : _AdminDrawer(
              currentPath: currentPath,
              userEmail: user?.email ?? '',
              onLogout: () => ref.read(adminSessionProvider).signOut(),
            ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: showBottomNav
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) => _navigateTab(context, index),
              backgroundColor: AppColors.white,
              indicatorColor: AppColors.emerald100,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(
                    Icons.analytics,
                    color: AppColors.emerald800,
                  ),
                  label: 'Riset Pasar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.apartment_outlined),
                  selectedIcon: Icon(
                    Icons.apartment,
                    color: AppColors.emerald800,
                  ),
                  label: 'Properti',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_ind_outlined),
                  selectedIcon: Icon(
                    Icons.assignment_ind,
                    color: AppColors.emerald800,
                  ),
                  label: 'Leads',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(
                    Icons.tune,
                    color: AppColors.emerald800,
                  ),
                  label: 'Master',
                ),
              ],
            )
          : null,
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.currentPath,
    required this.userEmail,
    required this.onLogout,
  });

  final String currentPath;
  final String userEmail;
  final Future<void> Function() onLogout;

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
                      color: AppColors.emerald600,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: AppColors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '${CompanyConfig.brandName} Admin',
                          style: AppTypography.h3,
                        ),
                        Text(
                          userEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              icon: Icons.analytics_outlined,
              label: 'Ringkasan & Riset Pasar',
              selected: currentPath == '/dashboard',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/dashboard');
              },
            ),
            _DrawerItem(
              icon: Icons.apartment_outlined,
              label: 'Kelola Properti',
              selected: currentPath.startsWith('/properties'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/properties');
              },
            ),
            _DrawerItem(
              icon: Icons.assignment_ind_outlined,
              label: 'Leads Booking',
              selected: currentPath.startsWith('/bookings'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/bookings');
              },
            ),
            _DrawerItem(
              icon: Icons.tune_outlined,
              label: 'Master Kategori, Daerah & Akun',
              selected: currentPath == '/master-data',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/master-data');
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onLogout();
                },
                icon: const Icon(Icons.logout, color: AppColors.errorText),
                label: const Text(
                  'Keluar dari Admin',
                  style: TextStyle(color: AppColors.errorText),
                ),
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

/// Badge status funnel booking (`bookings.funnel_status`).
class FunnelStatusBadge extends StatelessWidget {
  const FunnelStatusBadge({super.key, required this.status});

  final FunnelStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      FunnelStatus.newLead => (AppColors.emerald100, AppColors.emerald800),
      FunnelStatus.contacted => (AppColors.slate100, AppColors.slate900),
      FunnelStatus.surveyScheduled => (AppColors.warningBg, AppColors.warningText),
      FunnelStatus.officeVisit => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      FunnelStatus.closedWon => (AppColors.emerald500, AppColors.white),
      FunnelStatus.closedLost => (AppColors.errorBg, AppColors.errorText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        status.label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Tampilan angka dilihat read-only berikon mata + gembok (Figma `1:3513` / `1:3710`).
class ViewsLockBadge extends StatelessWidget {
  const ViewsLockBadge({super.key, required this.viewsCount});

  final int viewsCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.visibility_outlined,
            size: 14,
            color: AppColors.slate600,
          ),
          const SizedBox(width: 4),
          Text(
            AppFormatters.number(viewsCount),
            style: AppTypography.caption.copyWith(
              color: AppColors.slate900,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.lock_outline,
            size: 12,
            color: AppColors.slate500,
          ),
        ],
      ),
    );
  }
}

/// Banner penjelas read-only `views_count` sesuai Figma `1:3389`.
class ReadOnlyViewsBanner extends StatelessWidget {
  const ReadOnlyViewsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.slate200),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.lock_outline,
            size: 18,
            color: AppColors.slate600,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Jumlah dilihat dihitung otomatis dari halaman detail pelanggan dan tidak dapat diubah manual.',
              style: AppTypography.captionRegular,
            ),
          ),
        ],
      ),
    );
  }
}
