import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/survey_schedule_bottom_sheet.dart';

/// Dashboard Admin & Riset Pasar (`/dashboard`) sesuai Figma `1:2769` & `1:3038`.
/// Sengaja TIDAK menampilkan `Funnel booking` (`1:2684`) karena merupakan fitur Paket Full.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _daysWindow = 7;
  int? _selectedTrendPropertyId;
  bool _isLoading = true;
  Object? _error;
  AdminDashboardBundle? _bundle;

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
      final AdminDashboardBundle bundle =
          await ref.read(adminRepositoryProvider).loadDashboard(
                daysWindow: _daysWindow,
                trendPropertyId: _selectedTrendPropertyId,
              );
      if (mounted) {
        setState(() {
          _bundle = bundle;
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

  @override
  Widget build(BuildContext context) {
    final AdminDashboardBundle? bundle = _bundle;

    return AdminScaffold(
      currentPath: '/dashboard',
      title: 'Riset Pasar & Ringkasan',
      body: _isLoading && bundle == null
          ? const AsyncStateView.loading(
              message: 'Memuat analitik kunjungan dan pencarian...',
            )
          : _error != null && bundle == null
              ? AsyncStateView.error(
                  message: 'Gagal memuat data dashboard.',
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.pagePadding),
                    children: <Widget>[
                      _buildPeriodSelector(),
                      const SizedBox(height: AppSpacing.md),
                      if (bundle != null) ...<Widget>[
                        _buildMetricsGrid(bundle),
                        const SizedBox(height: AppSpacing.lg),
                        _buildTopPropertiesCard(bundle),
                        const SizedBox(height: AppSpacing.lg),
                        _buildViewTrendCard(bundle),
                        const SizedBox(height: AppSpacing.lg),
                        _buildLocationStatsCard(bundle),
                        const SizedBox(height: AppSpacing.lg),
                        _buildCategoryInterestCard(bundle),
                        const SizedBox(height: AppSpacing.lg),
                        _buildKeywordStatsCard(bundle),
                        const SizedBox(height: AppSpacing.lg),
                        _buildUpcomingSurveysCard(bundle),
                        const SizedBox(height: AppSpacing.lg),
                        _buildRecentLeadsCard(bundle),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.date_range_outlined,
              size: 20,
              color: AppColors.emerald600,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Periode:', style: AppTypography.sectionLabel),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _daysWindow,
                  isExpanded: true,
                  items: const <DropdownMenuItem<int>>[
                    DropdownMenuItem<int>(
                      value: 7,
                      child: Text('7 hari terakhir'),
                    ),
                    DropdownMenuItem<int>(
                      value: 30,
                      child: Text('30 hari terakhir'),
                    ),
                    DropdownMenuItem<int>(
                      value: 90,
                      child: Text('90 hari terakhir (per bulan)'),
                    ),
                  ],
                  onChanged: (int? value) {
                    if (value == null || value == _daysWindow) return;
                    setState(() => _daysWindow = value);
                    _load();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(AdminDashboardBundle bundle) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricCard(
                label: 'Total Dilihat',
                value: AppFormatters.number(bundle.totalViews),
                icon: Icons.visibility_outlined,
                subtitle: 'Otomatis dari pelanggan',
                showLock: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricCard(
                label: 'Total Pencarian',
                value: AppFormatters.number(bundle.totalSearches),
                icon: Icons.search,
                subtitle: '$_daysWindow hari terakhir',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricCard(
                label: 'Leads Aktif',
                value: AppFormatters.number(bundle.activeLeadsCount),
                icon: Icons.assignment_ind_outlined,
                subtitle: 'Perlu tindak lanjut',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricCard(
                label: 'Survei Terjadwal',
                value: AppFormatters.number(bundle.scheduledSurveysCount),
                icon: Icons.event_available_outlined,
                subtitle: 'Sudah dikonfirmasi',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopPropertiesCard(AdminDashboardBundle bundle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Properti Paling Sering Dilihat',
              style: AppTypography.h2,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (bundle.topProperties.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'Belum ada data kunjungan properti.',
                  style: AppTypography.bodyNormal,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: math.min(bundle.topProperties.length, 5),
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (BuildContext context, int index) {
                  final AdminPropertyTopItem item = bundle.topProperties[index];
                  return InkWell(
                    onTap: () => context.push('/properties/${item.id}/edit'),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: index == 0
                              ? AppColors.emerald500
                              : AppColors.slate100,
                          child: Text(
                            '${index + 1}',
                            style: AppTypography.caption.copyWith(
                              color: index == 0
                                  ? AppColors.white
                                  : AppColors.slate900,
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
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.sectionLabel,
                              ),
                              Text(
                                '${item.district} • ${item.categoryName}',
                                style: AppTypography.captionRegular,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ViewsLockBadge(viewsCount: item.viewsCount),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: AppSpacing.md),
            const ReadOnlyViewsBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTrendCard(AdminDashboardBundle bundle) {
    final List<AdminViewTrendPoint> points = bundle.viewTrend;
    final int maxYRaw = points.fold<int>(
      0,
      (int maxVal, AdminViewTrendPoint p) =>
          p.viewCount > maxVal ? p.viewCount : maxVal,
    );
    final double maxY = math.max(5, maxYRaw + 2).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Tren Kunjungan Properti', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Aktivitas kunjungan dari `property_view_logs`',
              style: AppTypography.captionRegular,
            ),
            const SizedBox(height: AppSpacing.md),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Filter Properti',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedTrendPropertyId,
                  isExpanded: true,
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Semua Properti'),
                    ),
                    ...bundle.topProperties.map(
                      (AdminPropertyTopItem item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(
                          item.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (int? value) {
                    setState(() => _selectedTrendPropertyId = value);
                    _load();
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (points.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'Belum ada catatan kunjungan pada rentang tanggal ini.',
                  style: AppTypography.bodyNormal,
                ),
              )
            else
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: AppColors.slate200,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value % 1 != 0) return const SizedBox.shrink();
                            return Text(
                              value.toInt().toString(),
                              style: AppTypography.captionRegular,
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: math.max(1, (points.length / 4).ceil())
                              .toDouble(),
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final int index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            final DateTime d = points[index].bucketDate;
                            final String label = _daysWindow > 45
                                ? '${d.month}/${d.year % 100}'
                                : '${d.day}/${d.month}';
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                label,
                                style: AppTypography.captionRegular,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: <LineChartBarData>[
                      LineChartBarData(
                        isCurved: true,
                        color: AppColors.emerald600,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.emerald500.withValues(alpha: 0.14),
                        ),
                        spots: <FlSpot>[
                          for (int i = 0; i < points.length; i++)
                            FlSpot(
                              i.toDouble(),
                              points[i].viewCount.toDouble(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStatsCard(AdminDashboardBundle bundle) {
    final List<AdminSearchStatItem> items = bundle.locationStats;
    final int maxSearch = items.fold<int>(
      1,
      (int m, AdminSearchStatItem e) => e.searchCount > m ? e.searchCount : m,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Daerah Paling Sering Dicari', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Berdasarkan pencarian pelanggan di katalog (`search_logs`)',
              style: AppTypography.captionRegular,
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              const Text(
                'Belum ada data pencarian menurut daerah pada periode ini.',
                style: AppTypography.bodyNormal,
              )
            else
              ...items.map((AdminSearchStatItem item) {
                final double ratio = (item.searchCount / maxSearch).clamp(0, 1);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.label,
                              style: AppTypography.bodyMedium15,
                            ),
                          ),
                          Text(
                            '${AppFormatters.number(item.searchCount)}x',
                            style: AppTypography.sectionLabel.copyWith(
                              color: AppColors.emerald800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 10,
                          backgroundColor: AppColors.slate100,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.emerald500,
                          ),
                        ),
                      ),
                      if (item.zeroResultCount > 0) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          '${item.zeroResultCount}x pencarian belum menemukan unit',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.warningText,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryInterestCard(AdminDashboardBundle bundle) {
    final List<AdminSearchStatItem> cats = bundle.categoryStats;
    final int total = cats.fold<int>(
      0,
      (int sum, AdminSearchStatItem item) => sum + item.searchCount,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Minat: Perumahan vs Ruko', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Berdasarkan filter kategori $_daysWindow hari terakhir',
              style: AppTypography.captionRegular,
            ),
            const SizedBox(height: AppSpacing.md),
            if (cats.isEmpty || total == 0)
              const Text(
                'Belum ada data filter kategori pada periode ini.',
                style: AppTypography.bodyNormal,
              )
            else ...<Widget>[
              SizedBox(
                height: 150,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: cats
                            .map((AdminSearchStatItem e) => e.searchCount)
                            .reduce(math.max) *
                        1.25,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final int idx = value.toInt();
                            if (idx < 0 || idx >= cats.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                cats[idx].label,
                                style: AppTypography.caption,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: <BarChartGroupData>[
                      for (int i = 0; i < cats.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: <BarChartRodData>[
                            BarChartRodData(
                              toY: cats[i].searchCount.toDouble(),
                              width: 34,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                              color: i == 0
                                  ? AppColors.emerald500
                                  : AppColors.slate900,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...cats.asMap().entries.map((MapEntry<int, AdminSearchStatItem> entry) {
                final AdminSearchStatItem item = entry.value;
                final int pct = ((item.searchCount / total) * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: entry.key == 0
                              ? AppColors.emerald500
                              : AppColors.slate900,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(item.label, style: AppTypography.bodyNormal),
                      ),
                      Text(
                        '${AppFormatters.number(item.searchCount)} ($pct%)',
                        style: AppTypography.sectionLabel,
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

  Widget _buildKeywordStatsCard(AdminDashboardBundle bundle) {
    final List<AdminSearchStatItem> keywords = bundle.keywordStats;
    final List<AdminSearchStatItem> zeroResultKeywords = keywords
        .where((AdminSearchStatItem k) => k.zeroResultCount > 0)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Kata Kunci Paling Sering Dicari',
              style: AppTypography.h2,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Termasuk kata kunci tanpa hasil (results_count = 0) sebagai peluang unit baru',
              style: AppTypography.captionRegular,
            ),
            const SizedBox(height: AppSpacing.md),
            if (keywords.isEmpty)
              const Text(
                'Belum ada kata kunci pencarian pada periode ini.',
                style: AppTypography.bodyNormal,
              )
            else ...<Widget>[
              ...keywords.map(
                (AdminSearchStatItem item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '"${item.label}"',
                          style: AppTypography.bodyMedium15,
                        ),
                      ),
                      if (item.zeroResultCount > 0) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusPill,
                            ),
                          ),
                          child: Text(
                            '${item.zeroResultCount}x kosong',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.warningText,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        '${AppFormatters.number(item.searchCount)}x',
                        style: AppTypography.sectionLabel,
                      ),
                    ],
                  ),
                ),
              ),
              if (zeroResultKeywords.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.emerald200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.emerald800,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Insight: "${zeroResultKeywords.first.label}" dicari '
                          '${zeroResultKeywords.first.zeroResultCount} kali tanpa unit tersedia.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.emerald950,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSurveysCard(AdminDashboardBundle bundle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('Jadwal Survei Terdekat', style: AppTypography.h2),
                ),
                TextButton(
                  onPressed: () => context.go('/bookings'),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            if (bundle.upcomingSurveys.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Belum ada jadwal survei yang dikonfirmasi.',
                  style: AppTypography.bodyNormal,
                ),
              )
            else
              ...bundle.upcomingSurveys.map((BookingWithProperty item) {
                final DateTime? date = item.booking.confirmedSurveyDate;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.emerald50,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.event_note,
                      color: AppColors.emerald600,
                    ),
                  ),
                  title: Text(
                    item.booking.customerName,
                    style: AppTypography.sectionLabel,
                  ),
                  subtitle: Text(
                    '${item.propertyTitle} • ${date != null ? AppFormatters.dateTime(date) : '-'}',
                    style: AppTypography.captionRegular,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await context.push('/bookings/${item.booking.id}');
                    _load();
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLeadsCard(AdminDashboardBundle bundle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('Leads Terbaru', style: AppTypography.h2),
                ),
                TextButton(
                  onPressed: () => context.go('/bookings'),
                  child: const Text('Kelola Leads'),
                ),
              ],
            ),
            if (bundle.recentBookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Belum ada pengajuan booking masuk.',
                  style: AppTypography.bodyNormal,
                ),
              )
            else
              ...bundle.recentBookings.map((BookingWithProperty item) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.booking.customerName,
                          style: AppTypography.sectionLabel,
                        ),
                      ),
                      FunnelStatusBadge(status: item.booking.funnelStatus),
                    ],
                  ),
                  subtitle: Text(
                    '${item.propertyTitle} • ${item.booking.intentType.label}',
                    style: AppTypography.captionRegular,
                  ),
                  trailing: IconButton(
                    tooltip: 'Tetapkan jadwal survei',
                    icon: const Icon(Icons.event_available_outlined),
                    onPressed: () async {
                      final BookingWithProperty? updated =
                          await showSurveyScheduleBottomSheet(
                        context,
                        item: item,
                        repository: ref.read(adminRepositoryProvider),
                      );
                      if (updated != null) {
                        _load();
                      }
                    },
                  ),
                  onTap: () async {
                    await context.push('/bookings/${item.booking.id}');
                    _load();
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.subtitle,
    this.showLock = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String subtitle;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: AppColors.emerald600),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ),
                if (showLock)
                  const Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: AppColors.slate500,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: AppTypography.h2),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: AppTypography.captionRegular),
          ],
        ),
      ),
    );
  }
}
