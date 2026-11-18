import 'package:material_ui/material_ui.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Kondisi tampilan standar (loading, kosong, galat) untuk setiap layar data.
class AsyncStateView extends StatelessWidget {
  const AsyncStateView.loading({
    super.key,
    this.message = 'Memuat data...',
  })  : _state = _ViewState.loading,
        title = null,
        icon = null,
        onRetry = null;

  const AsyncStateView.empty({
    super.key,
    required this.title,
    this.message = 'Belum ada data untuk ditampilkan.',
    this.icon = Icons.inbox_outlined,
    this.onRetry,
  }) : _state = _ViewState.empty;

  const AsyncStateView.error({
    super.key,
    this.title = 'Gagal Memuat Data',
    this.message =
        'Terjadi gangguan saat memuat data. Silakan periksa koneksi lalu coba lagi.',
    this.icon = Icons.wifi_off_rounded,
    required this.onRetry,
  }) : _state = _ViewState.error;

  final _ViewState _state;
  final String? title;
  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (_state == _ViewState.loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.emerald500),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: AppTypography.bodyNormal,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final isError = _state == _ViewState.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isError ? AppColors.errorBg : AppColors.emerald50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.info_outline,
                size: 28,
                color: isError ? AppColors.errorText : AppColors.emerald600,
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                title!,
                style: AppTypography.h3.copyWith(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodyNormal,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ViewState { loading, empty, error }
