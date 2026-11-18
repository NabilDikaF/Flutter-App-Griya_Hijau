import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../core/external_launcher.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/survey_schedule_bottom_sheet.dart';

/// Layar CRM Leads Booking (`/bookings`) sesuai Figma `1:3197` & Tugas 3.6.
/// Sengaja TIDAK menampilkan `Funnel booking` (`1:3102`) karena merupakan fitur Paket Full.
class AdminBookingsScreen extends ConsumerStatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  ConsumerState<AdminBookingsScreen> createState() =>
      _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends ConsumerState<AdminBookingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  FunnelStatus? _statusFilter;
  String _keyword = '';
  bool _isLoading = true;
  Object? _error;
  List<BookingWithProperty> _bookings = const <BookingWithProperty>[];

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
      final List<BookingWithProperty> items =
          await ref.read(adminRepositoryProvider).getBookings(
                statusFilter: _statusFilter,
                keyword: _keyword,
              );
      if (mounted) {
        setState(() {
          _bookings = items;
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
    final AdminRepository repo = ref.read(adminRepositoryProvider);

    return AdminScaffold(
      currentPath: '/bookings',
      title: 'Leads Booking',
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.pagePadding,
              AppSpacing.pagePadding,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  onChanged: (String value) {
                    _keyword = value;
                    _load();
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari nama pelanggan, kode booking, atau WA...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _keyword.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _keyword = '';
                              _load();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      FilterChip(
                        label: const Text('Semua'),
                        selected: _statusFilter == null,
                        onSelected: (_) {
                          setState(() => _statusFilter = null);
                          _load();
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      ...FunnelStatus.values.map((FunnelStatus status) {
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: FilterChip(
                            label: Text(status.label),
                            selected: _statusFilter == status,
                            onSelected: (_) {
                              setState(() => _statusFilter = status);
                              _load();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _bookings.isEmpty
                ? const AsyncStateView.loading(
                    message: 'Memuat data leads booking...',
                  )
                : _error != null && _bookings.isEmpty
                    ? AsyncStateView.error(
                        message: 'Gagal memuat data booking.',
                        onRetry: _load,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _bookings.isEmpty
                            ? ListView(
                                children: const <Widget>[
                                  SizedBox(height: 48),
                                  AsyncStateView.empty(
                                    icon: Icons.assignment_outlined,
                                    title: 'Belum ada leads yang cocok',
                                    message:
                                        'Ubah filter status atau kata kunci pencarian.',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.pagePadding,
                                  AppSpacing.sm,
                                  AppSpacing.pagePadding,
                                  AppSpacing.xl,
                                ),
                                itemCount: _bookings.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppSpacing.md),
                                itemBuilder: (BuildContext context, int index) {
                                  final BookingWithProperty item =
                                      _bookings[index];
                                  return _BookingLeadCard(
                                    item: item,
                                    onTap: () async {
                                      await context.push(
                                        '/bookings/${item.booking.id}',
                                      );
                                      await _load();
                                    },
                                    onChatWhatsapp: () =>
                                        ExternalLauncher.openWhatsappToNumber(
                                      context,
                                      whatsappNumber:
                                          item.booking.customerWhatsapp,
                                      prefilledMessage:
                                          'Halo ${item.booking.customerName}, kami dari tim pemasaran ${CompanyConfig.brandName} menindaklanjuti pengajuan (${item.booking.bookingCode}) untuk unit ${item.propertyTitle}.',
                                    ),
                                    onScheduleSurvey: () async {
                                      final BookingWithProperty? updated =
                                          await showSurveyScheduleBottomSheet(
                                        context,
                                        item: item,
                                        repository: repo,
                                      );
                                      if (updated != null) {
                                        await _load();
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _BookingLeadCard extends StatelessWidget {
  const _BookingLeadCard({
    required this.item,
    required this.onTap,
    required this.onChatWhatsapp,
    required this.onScheduleSurvey,
  });

  final BookingWithProperty item;
  final VoidCallback onTap;
  final VoidCallback onChatWhatsapp;
  final VoidCallback onScheduleSurvey;

  @override
  Widget build(BuildContext context) {
    final Booking b = item.booking;
    final DateTime? surveyDate =
        b.confirmedSurveyDate ?? b.preferredSurveyDate;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      b.customerName,
                      style: AppTypography.h3,
                    ),
                  ),
                  FunnelStatusBadge(status: b.funnelStatus),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${b.bookingCode} • ${item.propertyTitle}',
                style: AppTypography.bodyMedium15,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  Text(
                    b.intentType.label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.emerald800,
                    ),
                  ),
                  if (b.paymentPlan != null)
                    Text(
                      '• ${b.paymentPlan!.label}',
                      style: AppTypography.captionRegular,
                    ),
                  Text(
                    '• ${b.customerWhatsapp}',
                    style: AppTypography.captionRegular,
                  ),
                ],
              ),
              if (surveyDate != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.event_outlined,
                      size: 15,
                      color: AppColors.slate500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        b.confirmedSurveyDate != null
                            ? 'Survei pasti: ${AppFormatters.dateTime(surveyDate)}'
                            : 'Usulan survei: ${AppFormatters.dateTime(surveyDate)}',
                        style: AppTypography.captionRegular,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onChatWhatsapp,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.chat_outlined, size: 18),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Chat WA',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onScheduleSurvey,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'Tetapkan survei',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
