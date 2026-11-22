import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../core/external_launcher.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_scaffold.dart';

/// Layar Detail Lead Booking (`/bookings/:id`) sesuai Figma `1:3283` & Tugas 3.6.
/// Sengaja TIDAK menampilkan `Pesan WA terkirim` (`1:3262`) karena merupakan fitur Paket Full.
class AdminBookingDetailScreen extends ConsumerStatefulWidget {
  const AdminBookingDetailScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  ConsumerState<AdminBookingDetailScreen> createState() =>
      _AdminBookingDetailScreenState();
}

class _AdminBookingDetailScreenState
    extends ConsumerState<AdminBookingDetailScreen> {
  final TextEditingController _adminNotesController = TextEditingController();
  late final AdminSessionNotifier _session = ref.read(adminSessionProvider);
  bool _isLoading = true;
  bool _isSaving = false;
  Object? _error;

  BookingWithProperty? _item;
  late FunnelStatus _selectedStatus = FunnelStatus.newLead;
  DateTime? _confirmedSurveyDate;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _adminNotesController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!_session.isLoggedIn && mounted) {
      setState(() {
        _item = null;
        _confirmedSurveyDate = null;
        _adminNotesController.clear();
        _isLoading = false;
        _error = null;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final BookingWithProperty? loaded = await ref
          .read(adminRepositoryProvider)
          .getBookingById(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _item = loaded;
        if (loaded != null) {
          _selectedStatus = loaded.booking.funnelStatus;
          _confirmedSurveyDate = loaded.booking.confirmedSurveyDate;
          _adminNotesController.text = loaded.booking.adminNotes ?? '';
        }
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickSurveyDateTime() async {
    final DateTime now = DateTime.now();
    final DateTime base = (_confirmedSurveyDate ??
            _item?.booking.preferredSurveyDate ??
            now.add(const Duration(days: 1)))
        .toLocal();

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;

    setState(() {
      _confirmedSurveyDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveChanges() async {
    final BookingWithProperty? current = _item;
    if (current == null) return;

    final FunnelStatus previousStatus = current.booking.funnelStatus;

    setState(() => _isSaving = true);
    try {
      final AdminRepository repo = ref.read(adminRepositoryProvider);
      BookingWithProperty updated = await repo.updateBooking(
        bookingId: current.booking.id,
        funnelStatus: _selectedStatus,
        confirmedSurveyDate: _confirmedSurveyDate,
        adminNotes: _adminNotesController.text,
      );

      if (!mounted) return;
      setState(() {
        _item = updated;
        _isSaving = false;
      });

      if (_selectedStatus == FunnelStatus.closedWon &&
          previousStatus != FunnelStatus.closedWon &&
          current.propertyAvailabilityStatus != AvailabilityStatus.sold) {
        final AvailabilityStatus? nextPropertyStatus =
            await _askClosedWonPropertyStatus(updated);
        if (!mounted) return;
        if (nextPropertyStatus != null) {
          setState(() => _isSaving = true);
          await repo.updatePropertyAvailability(
            updated.booking.propertyId,
            nextPropertyStatus,
          );
          if (!mounted) return;
          setState(() {
            _item = updated.copyWith(
              propertyAvailabilityStatus: nextPropertyStatus,
            );
            _isSaving = false;
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status booking berhasil diperbarui.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<AvailabilityStatus?> _askClosedWonPropertyStatus(
    BookingWithProperty current,
  ) {
    return showDialog<AvailabilityStatus?>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Closing Berhasil — Ubah Status Unit?'),
        content: Text(
          'Booking telah berstatus Closing. Perbarui status ketersediaan "${current.propertyTitle}" menjadi Dipesan atau Terjual?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Biarkan Tetap'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(AvailabilityStatus.booked),
            child: const Text('Tandai Dipesan'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(AvailabilityStatus.sold),
            child: const Text('Tandai Terjual'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BookingWithProperty? item = _item;

    return AdminScaffold(
      currentPath: '/bookings',
      title: 'Detail Lead Booking',
      showBackButton: true,
      showBottomNav: false,
      body: _isLoading
          ? const AsyncStateView.loading(message: 'Memuat detail booking...')
          : _error != null || item == null
              ? AsyncStateView.error(
                  message: 'Data booking tidak ditemukan.',
                  onRetry: _load,
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  children: <Widget>[
                    _buildSummaryCard(item),
                    const SizedBox(height: AppSpacing.lg),
                    _buildCrmFormCard(item),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard(BookingWithProperty item) {
    final Booking b = item.booking;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(b.bookingCode, style: AppTypography.caption),
                ),
                FunnelStatusBadge(status: b.funnelStatus),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(b.customerName, style: AppTypography.h2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'WA: ${b.customerWhatsapp}',
              style: AppTypography.bodyMedium15,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: () => ExternalLauncher.openWhatsappToNumber(
                context,
                whatsappNumber: b.customerWhatsapp,
                prefilledMessage:
                    'Halo ${b.customerName}, kami dari ${CompanyConfig.brandName} menindaklanjuti pengajuan ${b.bookingCode} untuk ${item.propertyTitle}.',
              ),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Hubungi Pelanggan via WhatsApp'),
            ),
            const Divider(height: AppSpacing.xl),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Unit Properti', style: AppTypography.caption),
                      const SizedBox(height: 2),
                      Text(
                        item.propertyTitle,
                        style: AppTypography.sectionLabel,
                      ),
                    ],
                  ),
                ),
                AvailabilityBadge(status: item.propertyAvailabilityStatus),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoRow(label: 'Tujuan', value: b.intentType.label),
            if (b.paymentPlan != null)
              _InfoRow(label: 'Rencana Bayar', value: b.paymentPlan!.label),
            if (b.preferredSurveyDate != null)
              _InfoRow(
                label: 'Usulan Survei',
                value: AppFormatters.dateTime(b.preferredSurveyDate!),
              ),
            if (b.customerNotes != null && b.customerNotes!.isNotEmpty)
              _InfoRow(label: 'Catatan Pelanggan', value: b.customerNotes!),
          ],
        ),
      ),
    );
  }

  Widget _buildCrmFormCard(BookingWithProperty item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Tindak Lanjut & Status Funnel', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: FunnelStatus.values.map((FunnelStatus status) {
                return ChoiceChip(
                  label: Text(status.label),
                  selected: _selectedStatus == status,
                  onSelected: (_) => setState(() => _selectedStatus = status),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Jadwal Survei Terkonfirmasi', style: AppTypography.sectionLabel),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickSurveyDateTime,
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: Text(
                      _confirmedSurveyDate != null
                          ? AppFormatters.dateTime(_confirmedSurveyDate!)
                          : 'Pilih Tanggal & Jam Survei',
                    ),
                  ),
                ),
                if (_confirmedSurveyDate != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    tooltip: 'Hapus tanggal survei',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _confirmedSurveyDate = null),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('admin_booking_notes_input'),
              controller: _adminNotesController,
              maxLines: 4,
              maxLength: AdminRepository.maxAdminNotesLength,
              decoration: const InputDecoration(
                labelText: 'Catatan Admin',
                hintText: 'Catat hasil komunikasi WhatsApp, kelengkapan berkas KPR, dll.',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              key: const Key('admin_booking_save'),
              onPressed: _isSaving ? null : _saveChanges,
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
              label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(label, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyNormal),
          ),
        ],
      ),
    );
  }
}
