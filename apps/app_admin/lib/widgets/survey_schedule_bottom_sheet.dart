import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../data/admin_models.dart';
import '../data/admin_repository.dart';

/// Bottom sheet `Tetapkan Jadwal Survei` sesuai Figma `1:3316` & Tugas 3.6.
Future<BookingWithProperty?> showSurveyScheduleBottomSheet(
  BuildContext context, {
  required BookingWithProperty item,
  required AdminRepository repository,
}) {
  return showModalBottomSheet<BookingWithProperty>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (BuildContext sheetContext) => _SurveyScheduleSheet(
      item: item,
      repository: repository,
    ),
  );
}

class _SurveyScheduleSheet extends StatefulWidget {
  const _SurveyScheduleSheet({
    required this.item,
    required this.repository,
  });

  final BookingWithProperty item;
  final AdminRepository repository;

  @override
  State<_SurveyScheduleSheet> createState() => _SurveyScheduleSheetState();
}

class _SurveyScheduleSheetState extends State<_SurveyScheduleSheet> {
  late DateTime _selectedDateTime = _initialDateTime();
  late final TextEditingController _notesController = TextEditingController(
    text: widget.item.booking.adminNotes ?? '',
  );
  bool _isSaving = false;
  String? _error;

  DateTime _initialDateTime() {
    final DateTime? existing = widget.item.booking.confirmedSurveyDate ??
        widget.item.booking.preferredSurveyDate;
    if (existing != null) return existing.toLocal();
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime.isBefore(now) ? now : _selectedDateTime,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final BookingWithProperty updated = await widget.repository.updateBooking(
        bookingId: widget.item.booking.id,
        funnelStatus: FunnelStatus.surveyScheduled,
        confirmedSurveyDate: _selectedDateTime,
        adminNotes: _notesController.text,
      );
      if (mounted) {
        Navigator.of(context).pop(updated);
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
    final EdgeInsets insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        insets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Tetapkan Jadwal Survei', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${widget.item.booking.customerName} • ${widget.item.propertyTitle}',
              style: AppTypography.bodyNormal,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(AppFormatters.date(_selectedDateTime)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickTime,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(
                      '${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')} WIB',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan Admin (Opsional)',
                hintText: 'Contoh: Bertemu di kantor pemasaran 10 menit sebelumnya.',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTypography.caption.copyWith(color: AppColors.errorText),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.event_available),
              label: Text(
                _isSaving ? 'Menyimpan...' : 'Simpan & Tandai Jadwal Survei',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
