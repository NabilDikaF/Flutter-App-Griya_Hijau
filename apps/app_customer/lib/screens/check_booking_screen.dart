import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../core/external_launcher.dart';
import '../data/customer_repository.dart';
import '../widgets/customer_scaffold.dart';

/// Layar untuk customer mengecek progres pengajuan survei/booking unit (`/cek-booking`).
class CheckBookingScreen extends ConsumerStatefulWidget {
  const CheckBookingScreen({
    super.key,
    this.initialCode,
    this.initialWhatsapp,
  });

  final String? initialCode;
  final String? initialWhatsapp;

  @override
  ConsumerState<CheckBookingScreen> createState() => _CheckBookingScreenState();
}

class _CheckBookingScreenState extends ConsumerState<CheckBookingScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();

  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  List<CustomerBookingLookupResult> _results =
      const <CustomerBookingLookupResult>[];

  @override
  void initState() {
    super.initState();
    _applyInitialParams(triggerLookup: true);
  }

  @override
  void didUpdateWidget(covariant CheckBookingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCode != widget.initialCode ||
        oldWidget.initialWhatsapp != widget.initialWhatsapp) {
      _applyInitialParams(triggerLookup: true);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  void _applyInitialParams({required bool triggerLookup}) {
    final String code = (widget.initialCode ?? '').trim();
    final String wa = (widget.initialWhatsapp ?? '').trim();
    if (code.isNotEmpty) {
      _codeController.text = code;
    }
    if (wa.isNotEmpty) {
      _whatsappController.text = wa;
    }
    if (triggerLookup && (code.isNotEmpty || wa.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _performLookup();
        }
      });
    }
  }

  Future<void> _performLookup() async {
    final String code = _codeController.text.trim();
    final String wa = _whatsappController.text.trim();
    if (code.isEmpty && wa.isEmpty) {
      setState(() {
        _errorMessage =
            'Masukkan kode booking atau nomor WhatsApp untuk mengecek status.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final CustomerRepository repo = ref.read(customerRepositoryProvider);
      final List<CustomerBookingLookupResult> data =
          await repo.checkBookingStatus(
        bookingCode: code,
        customerWhatsapp: wa,
      );
      if (!mounted) return;
      setState(() {
        _results = data;
        _hasSearched = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _copyBookingCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kode booking $code berhasil disalin.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CustomerRepository repo = ref.watch(customerRepositoryProvider);

    return CustomerScaffold(
      currentPath: '/cek-booking',
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildHero(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildLookupForm(repo.isUsingLocalSeeder),
                const SizedBox(height: AppSpacing.lg),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMessage != null)
                  _StatusNoticeCard(
                    icon: Icons.error_outline,
                    backgroundColor: AppColors.errorBg,
                    borderColor: AppColors.errorText.withValues(alpha: 0.28),
                    iconColor: AppColors.errorText,
                    title: 'Tidak dapat memproses pencarian',
                    message: _errorMessage!,
                  )
                else if (_hasSearched && _results.isEmpty)
                  const _StatusNoticeCard(
                    icon: Icons.search_off_outlined,
                    backgroundColor: AppColors.white,
                    borderColor: AppColors.slate200,
                    iconColor: AppColors.slate500,
                    title: 'Data booking tidak ditemukan',
                    message:
                        'Periksa kembali kode booking (mis. BK-20261114-DEMO1) atau nomor WhatsApp yang Anda gunakan saat pengajuan.',
                  )
                else if (_hasSearched)
                  for (final CustomerBookingLookupResult item
                      in _results) ...<Widget>[
                    _BookingResultCard(
                      item: item,
                      onCopyCode: () => _copyBookingCode(item.booking.bookingCode),
                      onOpenProperty: item.propertySlug.isEmpty
                          ? null
                          : () => context.push('/properti/${item.propertySlug}'),
                      onOpenWhatsapp: () {
                        final String message =
                            'Halo admin ${CompanyConfig.brandName}, saya ingin menanyakan tindak lanjut booking dengan kode *${item.booking.bookingCode}* untuk unit *${item.propertyTitle}*.';
                        ExternalLauncher.openWhatsapp(
                          context,
                          prefilledMessage: message,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ]
                else
                  const _StatusNoticeCard(
                    icon: Icons.fact_check_outlined,
                    backgroundColor: AppColors.emerald50,
                    borderColor: AppColors.emerald200,
                    iconColor: AppColors.emerald800,
                    title: 'Cara mengecek status pengajuan',
                    message:
                        'Masukkan kode booking yang Anda terima setelah mengirim form (contoh: BK-20261114-DEMO1) atau masukkan nomor WhatsApp Anda.',
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
      color: AppColors.emerald50,
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
            'Beranda / Cek Booking',
            style: AppTypography.captionRegular.copyWith(
              color: AppColors.slate500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cek Status Booking',
            style: AppTypography.h2.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.emerald800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pantau progres pengajuan survei lokasi atau pemesanan unit Anda secara langsung.',
            style: AppTypography.bodyNormal.copyWith(
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _lookupInputDecoration(String hintText) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.slate200),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodyNormal.copyWith(color: AppColors.slate500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.emerald500, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.errorText),
      ),
    );
  }

  Widget _buildLookupForm(bool isLocalMode) {
    final TextStyle labelStyle = AppTypography.inputLabel.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.slate900,
    );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: const BorderSide(color: AppColors.slate200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Cari pengajuan Anda',
              style: AppTypography.h3.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Kode booking', style: labelStyle),
            const SizedBox(height: AppSpacing.fieldGap),
            TextFormField(
              key: const Key('check_booking_code_input'),
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              style: AppTypography.bodyNormal.copyWith(
                color: AppColors.slate900,
              ),
              decoration: _lookupInputDecoration('BK-20261114-DEMO1'),
              onFieldSubmitted: (_) => _performLookup(),
            ),
            if (isLocalMode) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    'Contoh kode:',
                    style: AppTypography.captionRegular.copyWith(
                      color: AppColors.slate600,
                    ),
                  ),
                  InkWell(
                    key: const Key('check_booking_demo_chip'),
                    onTap: () {
                      _codeController.text = 'BK-20261114-DEMO1';
                      _performLookup();
                    },
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusPill,
                        ),
                        border: Border.all(color: AppColors.emerald200),
                      ),
                      child: Text(
                        'BK-20261114-DEMO1',
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text('Nomor WhatsApp (opsional)', style: labelStyle),
            const SizedBox(height: AppSpacing.fieldGap),
            TextFormField(
              key: const Key('check_booking_wa_input'),
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.search,
              style: AppTypography.bodyNormal.copyWith(
                color: AppColors.slate900,
              ),
              decoration: _lookupInputDecoration('Contoh: 081234567890'),
              onFieldSubmitted: (_) => _performLookup(),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              key: const Key('check_booking_submit_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald500,
                foregroundColor: AppColors.white,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                textStyle: AppTypography.buttonLabel.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _isLoading ? null : _performLookup,
              child: const Text('Cek status booking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingResultCard extends StatelessWidget {
  const _BookingResultCard({
    required this.item,
    required this.onCopyCode,
    required this.onOpenProperty,
    required this.onOpenWhatsapp,
  });

  final CustomerBookingLookupResult item;
  final VoidCallback onCopyCode;
  final VoidCallback? onOpenProperty;
  final VoidCallback onOpenWhatsapp;

  @override
  Widget build(BuildContext context) {
    final Booking booking = item.booking;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: const BorderSide(color: AppColors.slate200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.emerald200),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: InkWell(
                      onTap: onCopyCode,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Kode booking',
                            style: AppTypography.captionRegular.copyWith(
                              fontSize: 11,
                              color: AppColors.slate600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            booking.bookingCode,
                            style: AppTypography.bodyMedium15.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.emerald800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FunnelStatusBadge(status: booking.funnelStatus),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _BookingProgressStepper(status: booking.funnelStatus),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: onOpenProperty,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.emerald100,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(
                        Icons.apartment_outlined,
                        color: AppColors.emerald800,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.propertyTitle,
                            style: AppTypography.sectionLabel.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.rupiah(item.propertyPrice),
                            style: AppTypography.sectionLabel.copyWith(
                              color: AppColors.emerald600,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item.locationLabel.isNotEmpty)
                            Text(
                              item.locationLabel,
                              style: AppTypography.captionRegular.copyWith(
                                color: AppColors.slate600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(label: 'Nama pemohon', value: booking.customerName),
            const Divider(height: 18, color: AppColors.slate100),
            _DetailRow(
              label: 'Nomor WhatsApp',
              value: booking.customerWhatsapp,
            ),
            const Divider(height: 18, color: AppColors.slate100),
            _DetailRow(
              label: 'Tujuan',
              value: booking.intentType == IntentType.surveyLocation
                  ? 'Survei lokasi'
                  : booking.intentType.label,
            ),
            if (booking.preferredSurveyDate != null) ...<Widget>[
              const Divider(height: 18, color: AppColors.slate100),
              _DetailRow(
                label: 'Rencana survei',
                value: AppFormatters.dateTime(booking.preferredSurveyDate!),
              ),
            ],
            if (booking.confirmedSurveyDate != null) ...<Widget>[
              const Divider(height: 18, color: AppColors.slate100),
              _DetailRow(
                label: 'Jadwal terkonfirmasi',
                value: AppFormatters.dateTime(booking.confirmedSurveyDate!),
                highlight: true,
              ),
            ],
            if (booking.paymentPlan != null) ...<Widget>[
              const Divider(height: 18, color: AppColors.slate100),
              _DetailRow(
                label: 'Rencana pembayaran',
                value: booking.paymentPlan!.label,
              ),
            ],
            if ((booking.customerNotes ?? '').trim().isNotEmpty) ...<Widget>[
              const Divider(height: 18, color: AppColors.slate100),
              _DetailRow(
                label: 'Catatan',
                value: booking.customerNotes!.trim(),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              key: const Key('check_booking_wa_admin_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald500,
                foregroundColor: AppColors.white,
                minimumSize: const Size(0, AppSpacing.whatsappButtonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                textStyle: AppTypography.buttonLabel.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onOpenWhatsapp,
              child: const Text('Hubungi admin via WhatsApp'),
            ),
            if (onOpenProperty != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.emerald600,
                  minimumSize: const Size(0, AppSpacing.buttonHeight),
                  side: const BorderSide(
                    color: AppColors.emerald500,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  textStyle: AppTypography.buttonLabel.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onOpenProperty,
                child: const Text('Lihat detail properti'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FunnelStatusBadge extends StatelessWidget {
  const _FunnelStatusBadge({required this.status});

  final FunnelStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      FunnelStatus.newLead => (
          AppColors.slate100,
          AppColors.slate600,
          status.label,
        ),
      FunnelStatus.contacted => (
          AppColors.warningBg,
          AppColors.warningText,
          status.label,
        ),
      FunnelStatus.surveyScheduled => (
          AppColors.emerald100,
          AppColors.emerald800,
          'Jadwal survei',
        ),
      FunnelStatus.officeVisit => (
          AppColors.emerald100,
          AppColors.emerald800,
          status.label,
        ),
      FunnelStatus.closedWon => (
          AppColors.emerald600,
          AppColors.white,
          status.label,
        ),
      FunnelStatus.closedLost => (
          AppColors.errorBg,
          AppColors.errorText,
          status.label,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BookingProgressStepper extends StatelessWidget {
  const _BookingProgressStepper({required this.status});

  final FunnelStatus status;

  int get _activeStep => switch (status) {
        FunnelStatus.newLead => 0,
        FunnelStatus.contacted => 1,
        FunnelStatus.surveyScheduled || FunnelStatus.officeVisit => 2,
        FunnelStatus.closedWon => 3,
        FunnelStatus.closedLost => -1,
      };

  @override
  Widget build(BuildContext context) {
    if (status == FunnelStatus.closedLost) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.errorBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Text(
          'Pengajuan ini berstatus Batal. Silakan ajukan ulang atau hubungi admin jika ingin menjadwalkan survei baru.',
          style: AppTypography.captionRegular.copyWith(
            color: AppColors.errorText,
          ),
        ),
      );
    }

    const List<String> labels = <String>[
      'Baru',
      'Dihubungi',
      'Survei/Kantor',
      'Selesai',
    ];
    final int current = _activeStep;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == current
                        ? AppColors.emerald600
                        : i < current
                            ? AppColors.emerald100
                            : AppColors.slate100,
                    border: Border.all(
                      color: i <= current
                          ? AppColors.emerald600
                          : AppColors.slate200,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: i < current
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.emerald800,
                        )
                      : Text(
                          '${i + 1}',
                          style: AppTypography.caption.copyWith(
                            color: i == current
                                ? AppColors.white
                                : AppColors.slate600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: i == current
                        ? AppColors.emerald800
                        : AppColors.slate600,
                    fontWeight:
                        i == current ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: AppTypography.captionRegular.copyWith(
              fontSize: 13,
              color: AppColors.slate600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.inputLabel.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.emerald800 : AppColors.slate900,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusNoticeCard extends StatelessWidget {
  const _StatusNoticeCard({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppTypography.sectionLabel),
                  const SizedBox(height: AppSpacing.xs),
                  Text(message, style: AppTypography.bodyNormal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
