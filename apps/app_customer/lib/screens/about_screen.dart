import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../core/external_launcher.dart';
import '../widgets/customer_scaffold.dart';

/// Layar Tentang Kami (`/tentang-kami`) sesuai Figma `Tentang Kami - Mobile` & Tugas 2.1.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const List<({String title, String body, IconData icon})> _advantages =
      <({String title, String body, IconData icon})>[
    (
      title: 'Lokasi Strategis',
      body: 'Dekat akses tol, sekolah, rumah sakit, dan pusat belanja.',
      icon: Icons.location_on_outlined,
    ),
    (
      title: 'Legalitas SHM / HGB',
      body: 'Sertifikat pecahan resmi dan IMB/PBG lengkap untuk setiap unit.',
      icon: Icons.verified_outlined,
    ),
    (
      title: 'Konstruksi Berkualitas',
      body: 'Spesifikasi material terstandar dengan pengawasan ketat di lapangan.',
      icon: Icons.home_work_outlined,
    ),
    (
      title: 'Pendampingan KPR',
      body: 'Tim marketing siap membantu simulasi hingga akad kredit di bank rekanan.',
      icon: Icons.calculate_outlined,
    ),
  ];

  static const List<({String name, String area, String summary})> _projects =
      <({String name, String area, String summary})>[
    (
      name: 'Griya Hijau Residence Sukamaju',
      area: 'Kec. Sukamaju, Bandung',
      summary: 'Kawasan hunian asri 1 & 2 lantai dengan keamanan 24 jam.',
    ),
    (
      name: 'Ruko Sentra Niaga Sari Indah',
      area: 'Kec. Sari Indah, Bandung',
      summary: 'Area ruko komersial jalur utama dengan parkir luas.',
    ),
    (
      name: 'Harmoni Alam Cluster',
      area: 'Kec. Tanjung Baru, Bandung',
      summary: 'Cluster keluarga nyaman dekat fasilitas pendidikan dan RS.',
    ),
  ];

  static const List<({String year, String title, String detail})> _milestones =
      <({String year, String title, String detail})>[
    (
      year: '2012',
      title: 'Pendirian PT Rindang Alam',
      detail: 'Memulai proyek cluster hunian perdana sebanyak 45 unit.',
    ),
    (
      year: '2016',
      title: 'Ekspansi Area Komersial',
      detail: 'Meluncurkan kawasan ruko niaga pertama di jalur utama kota.',
    ),
    (
      year: '2020',
      title: '500+ Unit Diserahterimakan',
      detail: 'Seluruh unit terjual dengan sertifikat SHM/HGB tuntas.',
    ),
    (
      year: '2025',
      title: 'Pengembangan Kawasan Baru',
      detail: 'Memperluas katalog digital untuk mempermudah survei & booking.',
    ),
  ];

  static const List<({String name, String role})> _team =
      <({String name, String role})>[
    (name: 'Hendra Wijaya', role: 'Direktur Utama'),
    (name: 'Siti Rahmawati', role: 'Manajer Pemasaran & KPR'),
    (name: 'Bambang Pratama', role: 'Kepala Teknik & Konstruksi'),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      currentPath: '/tentang-kami',
      title: 'Tentang Kami',
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildHero(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text('Cerita Kami', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  CompanyConfig.aboutStory,
                  style: AppTypography.bodyMedium15,
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
                    return Card(
                      color: AppColors.emerald50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        side: const BorderSide(color: AppColors.emerald200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
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
                              style: AppTypography.caption.copyWith(
                                color: AppColors.emerald950,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text('Visi & Misi', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.md),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Visi Perusahaan', style: AppTypography.h3),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          CompanyConfig.vision,
                          style: AppTypography.bodyNormal,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('Misi Perusahaan', style: AppTypography.h3),
                        const SizedBox(height: AppSpacing.sm),
                        for (final String mission
                            in CompanyConfig.missions) ...<Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: AppColors.emerald600,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  mission,
                                  style: AppTypography.bodyNormal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text('Keunggulan Kami', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.md),
                for (final item in _advantages) ...<Widget>[
                  Card(
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Icon(item.icon, color: AppColors.emerald600),
                      ),
                      title: Text(item.title, style: AppTypography.sectionLabel),
                      subtitle: Text(item.body, style: AppTypography.bodyNormal),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Text('Proyek Kami', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.md),
                for (final project in _projects) ...<Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(project.name, style: AppTypography.sectionLabel),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            project.area,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.emerald600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(project.summary, style: AppTypography.bodyNormal),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Text('Perjalanan Kami', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.md),
                for (final milestone in _milestones) ...<Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.cardPadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.emerald100,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusPill),
                            ),
                            child: Text(
                              milestone.year,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.emerald800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  milestone.title,
                                  style: AppTypography.sectionLabel,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  milestone.detail,
                                  style: AppTypography.bodyNormal,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Text('Tim Kami', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.md),
                for (final member in _team) ...<Widget>[
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.emerald100,
                        foregroundColor: AppColors.emerald800,
                        child: Text(
                          member.name.substring(0, 1),
                          style: AppTypography.sectionLabel,
                        ),
                      ),
                      title:
                          Text(member.name, style: AppTypography.sectionLabel),
                      subtitle:
                          Text(member.role, style: AppTypography.bodyNormal),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Text('Kunjungi Kami', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Kantor Pemasaran ${CompanyConfig.displayBrand}',
                          style: AppTypography.sectionLabel,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          CompanyConfig.officeAddress,
                          style: AppTypography.bodyNormal,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          '${CompanyConfig.officeHours} • Telp/WA: ${CompanyConfig.officePhoneDisplay}',
                          style: AppTypography.captionRegular,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: () => ExternalLauncher.openGoogleMaps(
                            context,
                            latitude: CompanyConfig.officeLatitude,
                            longitude: CompanyConfig.officeLongitude,
                          ),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Buka di Google Maps'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.emerald950,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Siap survei lokasi bersama kami?',
                        style: AppTypography.h3.copyWith(color: AppColors.white),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Pilih unit properti di katalog atau langsung konsultasi jadwal bersama tim pemasaran.',
                        style: AppTypography.bodyNormal.copyWith(
                          color: AppColors.emerald100,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton(
                        onPressed: () => context.go('/katalog'),
                        child: const Text('Jadwalkan Survei'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppColors.white,
                          side: const BorderSide(color: AppColors.emerald200),
                        ),
                        onPressed: () => ExternalLauncher.openWhatsapp(
                          context,
                          prefilledMessage:
                              'Halo admin ${CompanyConfig.brandName}, saya ingin menjadwalkan survei lokasi properti.',
                        ),
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: const Text('Hubungi via WhatsApp'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const CustomerFooter(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      color: AppColors.emerald950,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Beranda / Tentang Kami',
            style: AppTypography.caption.copyWith(color: AppColors.emerald200),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tentang ${CompanyConfig.brandName}',
            style: AppTypography.h2.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            CompanyConfig.shortDescription,
            style: AppTypography.bodyMedium15.copyWith(
              color: AppColors.emerald100,
            ),
          ),
        ],
      ),
    );
  }
}
