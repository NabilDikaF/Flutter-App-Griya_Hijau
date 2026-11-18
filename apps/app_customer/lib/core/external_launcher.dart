import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utilitas untuk membuka tautan eksternal (WhatsApp & Google Maps).
abstract final class ExternalLauncher {
  static Future<void> openWhatsapp(
    BuildContext context, {
    String? prefilledMessage,
  }) async {
    final String text = (prefilledMessage ?? '').trim();
    final Uri uri = Uri.https(
      'wa.me',
      '/${CompanyConfig.officeWhatsapp}',
      text.isEmpty ? null : <String, String>{'text': text},
    );
    await _launchExternal(
      context,
      uri,
      fallbackError: 'Tidak dapat membuka WhatsApp di perangkat ini.',
    );
  }

  static const Set<String> _allowedMapsHosts = <String>{
    'maps.google.com',
    'www.google.com',
    'google.com',
    'maps.app.goo.gl',
    'goo.gl',
  };

  /// Memastikan URL Google Maps memakai HTTPS dengan domain Google resmi.
  static bool isAllowedGoogleMapsUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https') return false;
    final String host = uri.host.toLowerCase();
    if (_allowedMapsHosts.contains(host)) return true;
    return host.endsWith('.google.com') || host.endsWith('.google.co.id');
  }

  static Future<void> openGoogleMaps(
    BuildContext context, {
    String? googleMapsUrl,
    double? latitude,
    double? longitude,
  }) async {
    final String? rawUrl = googleMapsUrl?.trim();
    Uri? targetUri;
    bool hadInvalidUrl = false;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      final Uri? parsed = Uri.tryParse(rawUrl);
      if (parsed != null && isAllowedGoogleMapsUri(parsed)) {
        targetUri = parsed;
      } else {
        hadInvalidUrl = true;
      }
    }
    if (targetUri == null && latitude != null && longitude != null) {
      targetUri = Uri.https(
        'www.google.com',
        '/maps/search/',
        <String, String>{
          'api': '1',
          'query': '$latitude,$longitude',
        },
      );
    }
    if (targetUri == null) {
      _showError(
        context,
        hadInvalidUrl
            ? 'Tautan Google Maps tidak valid.'
            : 'Koordinat lokasi belum tersedia.',
      );
      return;
    }

    await _launchExternal(
      context,
      targetUri,
      fallbackError: 'Tidak dapat membuka aplikasi Google Maps.',
    );
  }

  static Future<void> _launchExternal(
    BuildContext context,
    Uri uri, {
    required String fallbackError,
  }) async {
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showError(context, fallbackError);
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context, fallbackError);
      }
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
