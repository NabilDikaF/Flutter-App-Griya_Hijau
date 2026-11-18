import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../core/env_config.dart';
import '../core/external_launcher.dart';

/// Pemilih titik koordinat properti (`latitude`, `longitude`) untuk `Tugas 3.5`.
/// Admin dapat mengetuk/menggeser pin GoogleMap secara langsung atau menempel
/// tautan Google Maps agar koordinat diekstrak otomatis.
class LocationPickerField extends StatefulWidget {
  const LocationPickerField({
    super.key,
    required this.latitudeController,
    required this.longitudeController,
    required this.googleMapsUrlController,
    this.onCoordinatesChanged,
  });

  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController googleMapsUrlController;
  final VoidCallback? onCoordinatesChanged;

  /// Mengekstrak `(latitude, longitude)` dari tautan Google Maps atau string koordinat.
  static (double, double)? tryParseLatLngFromUrl(String raw) {
    final String normalized =
        raw.trim().replaceAll('%2C', ',').replaceAll('%2c', ',');
    if (normalized.isEmpty) return null;

    final List<RegExp> patterns = <RegExp>[
      RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)'),
      RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
      RegExp(
        r'[?&](?:q|query|ll|center)=(?:loc:)?(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
      ),
      RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$'),
    ];

    for (final RegExp pattern in patterns) {
      final RegExpMatch? match = pattern.firstMatch(normalized);
      if (match == null) continue;
      final double? lat = double.tryParse(match.group(1) ?? '');
      final double? lng = double.tryParse(match.group(2) ?? '');
      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        return (lat, lng);
      }
    }
    return null;
  }

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  GoogleMapController? _mapController;

  double get _currentLat =>
      double.tryParse(widget.latitudeController.text.trim()) ??
      CompanyConfig.officeLatitude;

  double get _currentLng =>
      double.tryParse(widget.longitudeController.text.trim()) ??
      CompanyConfig.officeLongitude;

  bool get _hasValidCoordinates {
    final double? lat = double.tryParse(widget.latitudeController.text.trim());
    final double? lng = double.tryParse(widget.longitudeController.text.trim());
    return lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  void _applyCoordinates(
    double lat,
    double lng, {
    bool updateUrlField = true,
  }) {
    final String latText = lat.toStringAsFixed(6);
    final String lngText = lng.toStringAsFixed(6);
    widget.latitudeController.text = latText;
    widget.longitudeController.text = lngText;
    if (updateUrlField &&
        (widget.googleMapsUrlController.text.trim().isEmpty ||
            widget.googleMapsUrlController.text.startsWith(
              'https://maps.google.com/?q=',
            ))) {
      widget.googleMapsUrlController.text =
          'https://maps.google.com/?q=$latText,$lngText';
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(lat, lng)),
    );
    setState(() {});
    widget.onCoordinatesChanged?.call();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LatLng target = LatLng(_currentLat, _currentLng);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Pilih Koordinat Peta', style: AppTypography.sectionLabel),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Ketuk peta atau seret pin untuk menandai lokasi, atau tempel tautan Google Maps di bawah.',
          style: AppTypography.captionRegular,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (EnvConfig.hasMapsApiKey)
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.slate200),
            ),
            clipBehavior: Clip.antiAlias,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: target, zoom: 14),
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              onTap: (LatLng point) =>
                  _applyCoordinates(point.latitude, point.longitude),
              markers: <Marker>{
                Marker(
                  markerId: const MarkerId('selected_property'),
                  position: target,
                  draggable: true,
                  onDragEnd: (LatLng point) =>
                      _applyCoordinates(point.latitude, point.longitude),
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              children: const <Widget>[
                Icon(
                  Icons.map_outlined,
                  color: AppColors.emerald600,
                  size: 20,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Peta interaktif siap digunakan setelah MAPS_API_KEY aktif. Anda tetap dapat menempelkan tautan Google Maps di bawah.',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          key: const Key('property_maps_url_input'),
          controller: widget.googleMapsUrlController,
          keyboardType: TextInputType.url,
          validator: (String? value) {
            final String trimmed = (value ?? '').trim();
            if (trimmed.isEmpty) return null;
            final Uri? parsed = Uri.tryParse(trimmed);
            if (parsed == null || !ExternalLauncher.isAllowedGoogleMapsUri(parsed)) {
              return 'Gunakan tautan HTTPS Google Maps (mis. https://maps.google.com/...).';
            }
            return null;
          },
          onChanged: (String value) {
            final (double, double)? parsed =
                LocationPickerField.tryParseLatLngFromUrl(value);
            if (parsed != null) {
              _applyCoordinates(parsed.$1, parsed.$2, updateUrlField: false);
            } else {
              setState(() {});
            }
          },
          decoration: const InputDecoration(
            labelText: 'Tautan Google Maps',
            hintText: 'https://maps.google.com/?q=-6.914744,107.609810',
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _hasValidCoordinates
              ? 'Titik pin aktif: ${widget.latitudeController.text}, ${widget.longitudeController.text}'
              : widget.googleMapsUrlController.text.trim().isNotEmpty
                  ? 'Tautan Google Maps tersimpan (koordinat tidak terbaca otomatis, tombol Petunjuk Arah tetap memakai tautan ini).'
                  : 'Belum ada titik lokasi. Ketuk peta atau tempel tautan Google Maps.',
          style: AppTypography.captionRegular,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _hasValidCoordinates ||
                    widget.googleMapsUrlController.text.trim().isNotEmpty
                ? () => ExternalLauncher.openGoogleMaps(
                      context,
                      googleMapsUrl: widget.googleMapsUrlController.text.trim(),
                      latitude: double.tryParse(
                        widget.latitudeController.text.trim(),
                      ),
                      longitude: double.tryParse(
                        widget.longitudeController.text.trim(),
                      ),
                    )
                : null,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Pratinjau di Google Maps'),
          ),
        ),
      ],
    );
  }
}
