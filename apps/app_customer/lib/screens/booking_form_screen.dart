import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../data/customer_repository.dart';
import '../widgets/customer_scaffold.dart';
import 'booking_success_screen.dart';

/// Layar Formulir Booking & Jadwal Survei (`/properti/:slug/booking`) sesuai Figma & Tugas 2.6.
class BookingFormScreen extends ConsumerStatefulWidget {
  const BookingFormScreen({
    super.key,
    required this.slug,
    this.initialProperty,
  });

  final String slug;
  final Property? initialProperty;

  /// Memvalidasi bahwa tanggal & jam survei berada di masa depan dalam batas 180 hari.
  static String? validateSurveyDateTime(
    DateTime? candidate, {
    DateTime? now,
  }) {
    if (candidate == null) {
      return 'Silakan pilih tanggal & jam survei lokasi terlebih dahulu.';
    }
    final DateTime refNow = now ?? DateTime.now();
    if (!candidate.isAfter(refNow)) {
      return 'Tanggal & jam survei tidak boleh di masa lalu. Silakan pilih waktu yang akan datang.';
    }
    if (candidate.isAfter(refNow.add(const Duration(days: 180)))) {
      return 'Tanggal pilihan survei maksimal 180 hari ke depan.';
    }
    return null;
  }

  @override
  ConsumerState<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  static final RegExp _whatsappPattern = RegExp(r'^628[0-9]{8,12}$');

  Property? _property;
  bool _isLoadingProperty = true;
  Object? _loadError;

  IntentType _intentType = IntentType.surveyLocation;
  DateTime? _preferredSurveyDate;
  PaymentPlan _paymentPlan = PaymentPlan.kpr;

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _property = widget.initialProperty;
    if (_property != null) {
      _isLoadingProperty = false;
    } else {
      Future<void>.microtask(_loadProperty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProperty() async {
    setState(() {
      _isLoadingProperty = true;
      _loadError = null;
    });
    try {
      final Property? fetched =
          await ref.read(customerRepositoryProvider).getPropertyBySlug(
                widget.slug,
              );
      if (!mounted) return;
      setState(() {
        _property = fetched;
        _isLoadingProperty = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoadingProperty = false;
      });
    }
  }

  Future<void> _pickSurveyDateTime() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        _preferredSurveyDate ?? now.add(const Duration(days: 1));
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null || !mounted) return;

    final DateTime candidate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final String? validationError =
        BookingFormScreen.validateSurveyDateTime(candidate);
    if (validationError != null) {
      setState(() => _submitError = validationError);
      return;
    }

    setState(() {
      _preferredSurveyDate = candidate;
      _submitError = null;
    });
  }

  Future<void> _submit() async {
    final Property? raw = _property;
    if (raw == null || !raw.isPublished || !(raw.category?.isActive ?? false)) {
      return;
    }
    final Property property = raw;

    setState(() => _submitError = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_intentType == IntentType.surveyLocation) {
      final String? surveyError =
          BookingFormScreen.validateSurveyDateTime(_preferredSurveyDate);
      if (surveyError != null) {
        setState(() => _submitError = surveyError);
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final Booking created =
          await ref.read(customerRepositoryProvider).createBooking(
                BookingCreateInput(
                  propertyId: property.id,
                  customerName: _nameController.text.trim(),
                  customerWhatsapp: _whatsappController.text.trim(),
                  intentType: _intentType,
                  preferredSurveyDate: _intentType == IntentType.surveyLocation
                      ? _preferredSurveyDate
                      : null,
                  paymentPlan:
                      _intentType == IntentType.bookUnit ? _paymentPlan : null,
                  customerNotes: _notesController.text.trim().isEmpty
                      ? null
                      : _notesController.text.trim(),
                ),
              );

      if (!mounted) return;
      context.go(
        '/booking-berhasil',
        extra: BookingSuccessArgs(
          booking: created,
          propertyTitle: property.title,
          propertySlug: property.slug,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final String message =
          error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _isSubmitting = false;
        _submitError = message.isEmpty
            ? 'Gagal mengirim pengajuan booking. Silakan coba lagi.'
            : message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Property? raw = _property;
    final Property? property = (raw != null &&
            raw.isPublished &&
            (raw.category?.isActive ?? false))
        ? raw
        : null;

    return CustomerScaffold(
      currentPath: '/properti/${Uri.encodeComponent(widget.slug)}/booking',
      title: 'Formulir Booking',
      showBackButton: true,
      body: _isLoadingProperty
          ? const AsyncStateView.loading(message: 'Menyiapkan formulir...')
          : _loadError != null
              ? AsyncStateView.error(onRetry: _loadProperty)
              : property == null
                  ? AsyncStateView.empty(
                      title: 'Properti tidak ditemukan',
                      message:
                          'Unit yang dipilih tidak tersedia atau belum dipublikasikan.',
                      onRetry: () => context.go('/katalog'),
                    )
                  : _buildForm(property),
    );
  }

  Widget _buildForm(Property property) {
    final bool isAvailable =
        property.availabilityStatus == AvailabilityStatus.available;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CategoryBadge(label: property.category!.name),
                    const SizedBox(width: AppSpacing.sm),
                    AvailabilityBadge(status: property.availabilityStatus),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(property.title, style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${property.location?.displayName ?? '-'} • ${AppFormatters.rupiah(property.price)}',
                  style: AppTypography.bodyNormal.copyWith(
                    color: AppColors.emerald600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isAvailable) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              'Unit ini berstatus ${property.availabilityStatus.label} dan tidak dapat diajukan booking baru.',
              style: AppTypography.bodyNormal.copyWith(
                color: AppColors.warningText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Nama Lengkap *', style: AppTypography.inputLabel),
              const SizedBox(height: AppSpacing.fieldGap),
              TextFormField(
                controller: _nameController,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Budi Santoso',
                  counterText: '',
                ),
                validator: (String? value) {
                  if (value == null || value.trim().length < 2) {
                    return 'Nama lengkap wajib diisi (minimal 2 karakter).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Nomor WhatsApp Aktif *',
                style: AppTypography.inputLabel,
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              TextFormField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '6281234567890',
                  helperText: 'Wajib diawali 628 (11–15 digit tanpa spasi/tanda).',
                ),
                validator: (String? value) {
                  final String trimmed = (value ?? '').trim();
                  if (!_whatsappPattern.hasMatch(trimmed)) {
                    return 'Format nomor WhatsApp harus diawali 628 (contoh: 6281234567890).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Tujuan Anda *', style: AppTypography.inputLabel),
              const SizedBox(height: AppSpacing.sm),
              _IntentChoiceCard(
                title: 'Jadwalkan Survei Lokasi',
                subtitle: 'Kunjungi unit terlebih dahulu bersama tim marketing.',
                selected: _intentType == IntentType.surveyLocation,
                onTap: () => setState(() {
                  _intentType = IntentType.surveyLocation;
                  _submitError = null;
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              _IntentChoiceCard(
                title: 'Langsung Booking Unit',
                subtitle:
                    'Ajukan pemesanan unit dengan pilihan rencana pembayaran.',
                selected: _intentType == IntentType.bookUnit,
                onTap: () => setState(() {
                  _intentType = IntentType.bookUnit;
                  _submitError = null;
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_intentType == IntentType.surveyLocation) ...<Widget>[
                const Text(
                  'Tanggal & Jam Survei *',
                  style: AppTypography.inputLabel,
                ),
                const SizedBox(height: AppSpacing.fieldGap),
                OutlinedButton.icon(
                  onPressed: _pickSurveyDateTime,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    _preferredSurveyDate == null
                        ? 'Pilih Tanggal & Jam Survei'
                        : AppFormatters.dateTime(_preferredSurveyDate!),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    ActionChip(
                      label: const Text('Besok 10:00 WIB'),
                      onPressed: () {
                        final DateTime tomorrow =
                            DateTime.now().add(const Duration(days: 1));
                        setState(() {
                          _preferredSurveyDate = DateTime(
                            tomorrow.year,
                            tomorrow.month,
                            tomorrow.day,
                            10,
                            0,
                          );
                          _submitError = null;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Besok 14:00 WIB'),
                      onPressed: () {
                        final DateTime tomorrow =
                            DateTime.now().add(const Duration(days: 1));
                        setState(() {
                          _preferredSurveyDate = DateTime(
                            tomorrow.year,
                            tomorrow.month,
                            tomorrow.day,
                            14,
                            0,
                          );
                          _submitError = null;
                        });
                      },
                    ),
                  ],
                ),
              ] else ...<Widget>[
                const Text(
                  'Rencana Pembayaran *',
                  style: AppTypography.inputLabel,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: PaymentPlan.values.map((PaymentPlan plan) {
                    final bool selected = _paymentPlan == plan;
                    return ChoiceChip(
                      label: Text(plan.label),
                      selected: selected,
                      selectedColor: AppColors.emerald500,
                      backgroundColor: AppColors.white,
                      checkmarkColor: AppColors.white,
                      labelStyle: AppTypography.caption.copyWith(
                        color: selected ? AppColors.white : AppColors.slate900,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _paymentPlan = plan),
                    );
                  }).toList(growable: false),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Catatan Tambahan (Opsional)',
                style: AppTypography.inputLabel,
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Ingin diskusi simulasi KPR DP 15%',
                ),
              ),
              if (_submitError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(
                    _submitError!,
                    style: AppTypography.bodyNormal.copyWith(
                      color: AppColors.errorText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: (!isAvailable || _isSubmitting) ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Kirim Pengajuan Booking'),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Tanpa pembayaran di aplikasi. Tim pemasaran kami akan menghubungi Anda.',
                textAlign: TextAlign.center,
                style: AppTypography.captionRegular,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntentChoiceCard extends StatelessWidget {
  const _IntentChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald50 : AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected ? AppColors.emerald500 : AppColors.slate200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.emerald600 : AppColors.slate500,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTypography.sectionLabel.copyWith(
                      color:
                          selected ? AppColors.emerald950 : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.captionRegular),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
