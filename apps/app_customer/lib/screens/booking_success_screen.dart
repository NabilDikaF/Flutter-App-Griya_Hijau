import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../core/external_launcher.dart';
import '../widgets/customer_scaffold.dart';

/// Argumen ringkas hasil pengajuan booking untuk layar Konfirmasi.
class BookingSuccessArgs {
  const BookingSuccessArgs({
    required this.booking,
    required this.propertyTitle,
    required this.propertySlug,
  });

  final Booking booking;
  final String propertyTitle;
  final String propertySlug;
}

/// Layar Konfirmasi Booking (`/booking-berhasil`) sesuai Figma `1:2125` & Tugas 2.6.
class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, this.args});

  final BookingSuccessArgs? args;

  @override
  Widget build(BuildContext context) {
    final BookingSuccessArgs? data = args;
    if (data == null) {
      return CustomerScaffold(
        currentPath: '/booking-berhasil',
        title: 'Status Pengajuan',
        body: AsyncStateView.empty(
          title: 'Data pengajuan tidak ditemukan',
          message:
              'Silakan pilih properti dari katalog untuk mengajukan survei atau booking.',
          onRetry: () => context.go('/'),
        ),
      );
    }

    final Booking booking = data.booking;
    final String whatsappMessage =
        'Halo admin ${CompanyConfig.brandName}, saya baru mengajukan ${booking.intentType.label} '
        'dengan kode booking ${booking.bookingCode} untuk properti "${data.propertyTitle}" '
        'atas nama ${booking.customerName} (${booking.customerWhatsapp}).';

    return CustomerScaffold(
      currentPath: '/booking-berhasil',
      title: 'Pengajuan Diterima',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.emerald100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 42,
                color: AppColors.emerald600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Data Anda sudah kami terima',
            textAlign: TextAlign.center,
            style: AppTypography.h2,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Tim pemasaran kami akan menindaklanjuti pengajuan Anda melalui WhatsApp.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyNormal,
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.emerald50,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.emerald200),
                    ),
                    child: Column(
                      children: <Widget>[
                        const Text(
                          'Kode Booking',
                          style: AppTypography.captionRegular,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          booking.bookingCode,
                          style: AppTypography.h3.copyWith(
                            color: AppColors.emerald800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DetailRow(label: 'Properti', value: data.propertyTitle),
                  const Divider(height: AppSpacing.lg),
                  _DetailRow(label: 'Nama Pemohon', value: booking.customerName),
                  const Divider(height: AppSpacing.lg),
                  _DetailRow(
                    label: 'Nomor WhatsApp',
                    value: booking.customerWhatsapp,
                  ),
                  const Divider(height: AppSpacing.lg),
                  _DetailRow(label: 'Tujuan', value: booking.intentType.label),
                  if (booking.preferredSurveyDate != null) ...<Widget>[
                    const Divider(height: AppSpacing.lg),
                    _DetailRow(
                      label: 'Rencana Survei',
                      value: AppFormatters.dateTime(booking.preferredSurveyDate!),
                    ),
                  ],
                  if (booking.paymentPlan != null) ...<Widget>[
                    const Divider(height: AppSpacing.lg),
                    _DetailRow(
                      label: 'Rencana Pembayaran',
                      value: booking.paymentPlan!.label,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.whatsappButtonHeight),
            ),
            onPressed: () => ExternalLauncher.openWhatsapp(
              context,
              prefilledMessage: whatsappMessage,
            ),
            icon: const Icon(Icons.chat_outlined, size: 20),
            label: const Text('Hubungi Admin via WhatsApp'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('booking_success_check_status_button'),
            onPressed: () => context.go(
              '/cek-booking?code=${Uri.encodeComponent(booking.bookingCode)}',
            ),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('Cek Status Booking'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () => context.go('/'),
            child: const Text('Kembali ke Beranda'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 130,
          child: Text(label, style: AppTypography.captionRegular),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.sectionLabel,
          ),
        ),
      ],
    );
  }
}
